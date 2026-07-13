import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection_result.dart';
import '../models/motion_object.dart';
import '../models/tracked_object.dart';
import '../services/motion_estimator.dart';
import '../services/onnx_inference_service.dart';
import '../services/raw_yolo_decoder.dart';
import '../services/tracker.dart';

class CameraPreviewPanel extends StatefulWidget {
  const CameraPreviewPanel({
    required this.onnxService,
    required this.onDetections,
    this.onTrackedObjects,
    this.onMotionObjects,
    super.key,
  });

  final OnnxInferenceService onnxService;
  final void Function(List<DetectionResult> detections) onDetections;
  final void Function(List<TrackedObject> trackedObjects)? onTrackedObjects;
  final void Function(List<MotionObject> motionObjects)? onMotionObjects;

  @override
  State<CameraPreviewPanel> createState() => _CameraPreviewPanelState();
}

class _CameraPreviewPanelState extends State<CameraPreviewPanel> {
  static const Duration _inferenceInterval = Duration(milliseconds: 120);
  static bool get _isWidgetTest {
    final binding = WidgetsBinding.instance;
    return binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  final SimpleTracker _tracker = SimpleTracker();
  final MotionEstimator _motionEstimator = MotionEstimator();

  CameraController? _controller;
  String _status = 'Starting camera...';
  bool _isProcessing = false;
  bool _workerBusy = false;
  List<DetectionResult> _detections = const [];
  Size? _sensorSize;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);

  int _preprocessMs = 0;
  int _inferenceMs = 0;
  int _decodeMs = 0;
  int _totalMs = 0;
  int _lastFrameAcceptedAtMs = 0;

  Isolate? _workerIsolate;
  SendPort? _commandPort;
  ReceivePort _workerResponsePort = ReceivePort();
  bool _workerReady = false;
  bool _workerInitialized = false;

  @override
  void initState() {
    super.initState();
    if (_isWidgetTest) {
      _status = 'Camera disabled in tests';
      return;
    }
    _initWorker();
    Future.microtask(_startCamera);
  }

  void _initWorker() {
    _workerResponsePort.listen(_onWorkerMessage);
    Isolate.spawn(_workerEntry, _workerResponsePort.sendPort).then((isolate) {
      _workerIsolate = isolate;
    }).catchError((e) {
      debugPrint('[Camera] Worker spawn failed: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() { _status = 'Worker spawn failed: $e'; });
      });
    });
  }

  void _onWorkerMessage(dynamic message) {
    if (!mounted) return;

    // Handshake: worker sends back its SendPort
    if (message is SendPort) {
      _commandPort = message;
      _workerReady = true;
      _sendInitToWorker();
      return;
    }

if (message is Map<String, dynamic>) {
        // Worker ready confirmation
        if (message['ready'] == true) {
          _workerInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() { _status = 'Worker ready (TFLite)'; });
          });
          return;
        }
        // Worker error during init
        if (message['error'] != null) {
          debugPrint('[Camera] Worker init error: ${message['error']}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() { _status = 'Init error: ${message['error']}'; });
          });
          return;
        }
      // Detection results
      if (message['type'] == 'result') {
        _workerBusy = false;
        _isProcessing = false;
        _handleDetectionResult(message);
        return;
      }
    }

    // Unknown message – just reset flags
    _workerBusy = false;
    _isProcessing = false;
  }

  void _sendInitToWorker() {
    if (!_workerReady || _workerInitialized) return;
    if (!widget.onnxService.isLoaded) {
      // Model not loaded yet – retry after a short delay
      Future.delayed(const Duration(milliseconds: 50), _sendInitToWorker);
      return;
    }

    final modelBytes = widget.onnxService.modelBytes;
    if (modelBytes == null) return;

    _commandPort?.send(<String, dynamic>{
      'init': true,
      'modelBytes': modelBytes,
      'labels': widget.onnxService.labels,
    });
  }

  void _handleDetectionResult(Map<String, dynamic> message) {
    final rawDetections = message['detections'] as List<dynamic>?;
    if (rawDetections == null) return;

    final frameWidth = message['frameWidth'] as int;
    final frameHeight = message['frameHeight'] as int;
    if (_sensorSize == null || _sensorSize!.width != frameWidth || _sensorSize!.height != frameHeight) {
      _sensorSize = Size(frameWidth.toDouble(), frameHeight.toDouble());
    }
    final timestampMs = _lastFrameAcceptedAtMs;

    final detections = rawDetections.map((d) {
      final m = d as Map<String, dynamic>;
      return DetectionResult(
        label: m['label'] as String,
        confidence: (m['confidence'] as num).toDouble(),
        left: (m['left'] as num).toDouble(),
        top: (m['top'] as num).toDouble(),
        right: (m['right'] as num).toDouble(),
        bottom: (m['bottom'] as num).toDouble(),
      );
    }).toList();


    final trackedObjects = _tracker.update(
      detections: detections,
      timestampMs: timestampMs,
    );
    final motionObjects = _motionEstimator.update(
      trackedObjects: trackedObjects,
      frameHeightPx: frameHeight,
      timestampMs: timestampMs,
    );

    if (!mounted) return;
    widget.onDetections(detections);
    widget.onTrackedObjects?.call(trackedObjects);
    widget.onMotionObjects?.call(motionObjects);

    // Defer setState to avoid layout assertion from camera stream timing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _detections = detections;
        _preprocessMs = message['preprocessMs'] as int? ?? 0;
        _inferenceMs = message['inferenceMs'] as int? ?? 0;
        _decodeMs = message['decodeMs'] as int? ?? 0;
        _totalMs =
            DateTime.now().millisecondsSinceEpoch - _lastFrameAcceptedAtMs;
      });
    });
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setStatus('No camera found');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller?.dispose();
      _controller = controller;
      await controller.initialize();

      if (!mounted) return;

      // Set sensor size from preview size eagerly (avoids setState during camera stream)
      final ps = controller.value.previewSize;
      if (ps != null) {
        _sensorSize =
            ps.width > ps.height ? Size(ps.height, ps.width) : Size(ps.width, ps.height);
      }

      await controller.startImageStream(_onImage);

      setState(() {
        _status = 'Camera ready';
      });
    } on CameraException catch (error) {
      _setStatus('Camera error: ${error.code}');
    } catch (error) {
      _setStatus('Camera error: $error');
    }
  }

  void _onImage(CameraImage image) {
    if (!widget.onnxService.isLoaded) return;
    if (!_workerReady || !_workerInitialized) return;
    if (_isProcessing || _workerBusy) return;

    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < _inferenceInterval) {
      return;
    }

    _isProcessing = true;
    _workerBusy = true;
    _lastInferenceAt = now;
    _lastFrameAcceptedAtMs = now.millisecondsSinceEpoch;

    final yBytes = TransferableTypedData.fromList([image.planes[0].bytes]);
    final uBytes = TransferableTypedData.fromList([image.planes[1].bytes]);
    final vBytes = TransferableTypedData.fromList([image.planes[2].bytes]);
    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final w = image.width;
    final h = image.height;
    final needsRotate = w > h;

    _commandPort?.send(<dynamic>[
      w,
      h,
      yBytes,
      uBytes,
      vBytes,
      yRowStride,
      uvRowStride,
      uvPixelStride,
      needsRotate,
    ]);
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() {
      _status = status;
    });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _tracker.reset();
    _motionEstimator.reset();
    _workerResponsePort.close();
    _workerIsolate?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth;
        final areaHeight = constraints.maxHeight;

        return isReady
            ? Stack(
              children: [
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize?.height ?? 720,
                      height: controller.value.previewSize?.width ?? 1280,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
                if (_detections.isNotEmpty && _sensorSize != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BoundingBoxPainter(
                        detections: _detections,
                        sensorWidth: _sensorSize!.width,
                        sensorHeight: _sensorSize!.height,
                        areaWidth: areaWidth,
                        areaHeight: areaHeight,
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _PerfOverlay(
                    preprocessMs: _preprocessMs,
                    inferenceMs: _inferenceMs,
                    decodeMs: _decodeMs,
                    totalMs: _totalMs,
                  ),
                ),
              ],
            )
            : Center(
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white54),
              ),
            );
      },
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({
    required this.detections,
    required this.sensorWidth,
    required this.sensorHeight,
    required this.areaWidth,
    required this.areaHeight,
  });

  final List<DetectionResult> detections;
  final double sensorWidth;
  final double sensorHeight;
  final double areaWidth;
  final double areaHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final pw = sensorWidth;
    final ph = sensorHeight;
    final sw = areaWidth;
    final sh = areaHeight;

    final scale = (sw / pw) > (sh / ph) ? (sw / pw) : (sh / ph);
    final visibleW = sw / scale;
    final visibleH = sh / scale;
    final cropX = (pw - visibleW) / 2;
    final cropY = (ph - visibleH) / 2;

    for (final d in detections) {
      final camX = d.left * pw;
      final camY = d.top * ph;
      final camR = d.right * pw;
      final camB = d.bottom * ph;
      final camW = camR - camX;
      final camH = camB - camY;

      final visX = (camX - cropX) / visibleW * sw;
      final visY = (camY - cropY) / visibleH * sh;
      final visW = camW / visibleW * sw;
      final visH = camH / visibleH * sh;

      final color = _colorForLabel(d.label);

      final paint =
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0;
      canvas.drawRect(Rect.fromLTWH(visX, visY, visW, visH), paint);

      final bgPaint = Paint()..color = color.withAlpha(200);
      final textSpan = TextSpan(
        text: '${d.label} ${(d.confidence * 100).round()}%',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      canvas.drawRect(
        Rect.fromLTWH(visX, visY - tp.height - 4, tp.width + 6, tp.height + 4),
        bgPaint,
      );
      tp.paint(canvas, Offset(visX + 3, visY - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter old) => old.detections != detections;

  Color _colorForLabel(String label) {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
    ];
    return colors[label.hashCode % colors.length];
  }
}

// ---- Long-lived background worker (TFLite) ----

@pragma('vm:entry-point')
void _workerEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  Interpreter? interpreter;
  List<String> labels = const [];
  Float32List? inputBuffer;
  Float32List? outputBuffer;
  bool initialized = false;

  receivePort.listen((message) async {
    // Init message
    if (!initialized && message is Map<String, dynamic> && message['init'] == true) {
      try {
        final modelBytes = message['modelBytes'] as Uint8List;
        labels = List<String>.from(message['labels'] as List);

        final opts = InterpreterOptions();

        // GPU delegate (Android OpenCL/GLES) — typically 20-80ms inference
        try { opts.addDelegate(GpuDelegateV2()); } catch (_) {}
        // XNNPACK (CPU NEON fallback) — ~200-400ms if GPU fails
        try { opts.addDelegate(XNNPackDelegate()); } catch (_) {}

        interpreter = Interpreter.fromBuffer(modelBytes, options: opts);

        // Verify input/output shapes
        final inputShape = interpreter!.getInputTensor(0).shape;
        final outputShape = interpreter!.getOutputTensor(0).shape;
        debugPrint('[Worker] Input shape: $inputShape');
        debugPrint('[Worker] Output shape: $outputShape');

        // Pre-allocate buffers: NCHW input (3x640x640), output (15x8400 column-major)
        inputBuffer = Float32List(3 * 640 * 640);
        outputBuffer = Float32List(15 * 8400);

        initialized = true;
        debugPrint('[Worker] TFLite ready');
        mainSendPort.send(<String, dynamic>{'ready': true});
      } catch (e) {
        debugPrint('[Worker] Init error: $e');
        mainSendPort.send(<String, dynamic>{'error': e.toString()});
      }
      return;
    }

    if (!initialized) return;

    // Frame message
    if (message is List<dynamic> && message.length >= 9) {
      try {
        final preStart = DateTime.now();
        final args = message;

        final yMat = (args[2] as TransferableTypedData).materialize().asUint8List();
        final uMat = (args[3] as TransferableTypedData).materialize().asUint8List();
        final vMat = (args[4] as TransferableTypedData).materialize().asUint8List();

        _yuvToNchw(
          width: args[0] as int,
          height: args[1] as int,
          yBytes: yMat,
          uBytes: uMat,
          vBytes: vMat,
          yRowStride: args[5] as int,
          uvRowStride: args[6] as int,
          uvPixelStride: args[7] as int,
          needsRotate: args[8] as bool,
          out: inputBuffer!,
        );
        final preElapsed = DateTime.now().difference(preStart).inMilliseconds;

        final inferStart = DateTime.now();
        interpreter!.run(inputBuffer!.buffer, outputBuffer!.buffer);
        final inferElapsed = DateTime.now().difference(inferStart).inMilliseconds;

        final decodeStart = DateTime.now();
        const decoder = RawYoloDecoder();
        final decoded = decoder.decodeTfliteColumnar(
          rawOutput: outputBuffer!,
          labels: labels,
          confidenceThreshold: 0.35,
        );
        final detections = decoded.map((d) => <String, dynamic>{
          'label': d.label,
          'confidence': d.confidence,
          'left': d.left,
          'top': d.top,
          'right': d.right,
          'bottom': d.bottom,
        }).toList();
        final decodeElapsed = DateTime.now().difference(decodeStart).inMilliseconds;

        mainSendPort.send(<String, dynamic>{
          'type': 'result',
          'detections': detections,
          'preprocessMs': preElapsed,
          'inferenceMs': inferElapsed,
          'decodeMs': decodeElapsed,
          'frameWidth': (args[8] as bool) ? (args[1] as int) : (args[0] as int),
          'frameHeight': (args[8] as bool) ? (args[0] as int) : (args[1] as int),
        });
      } catch (e) {
        debugPrint('[Worker] Frame error: $e');
      }
    }
  });
}

/// Convert YUV420_888 → NCHW Float32 [0,1] with optional 90° CW rotation.
/// out must be [3 * 640 * 640] elements (NCHW layout: R, G, B channels each 640x640).
void _yuvToNchw({
  required int width,
  required int height,
  required Uint8List yBytes,
  required Uint8List uBytes,
  required Uint8List vBytes,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required bool needsRotate,
  required Float32List out,
}) {
  const int outSize = 640;
  const int stride = outSize * outSize;

  if (needsRotate) {
    final w = width;
    final h = height;
    for (var oy = 0; oy < outSize; oy++) {
      final srcXBase = (oy * w) ~/ outSize;
      for (var ox = 0; ox < outSize; ox++) {
        final srcX = srcXBase;
        final srcY = (h - 1) - (ox * h) ~/ outSize;

        final yIdx = srcY * yRowStride + srcX;
        final yVal = yBytes[yIdx] & 0xff;
        final uvY = srcY >> 1;
        final uvX = srcX >> 1;
        final uvIdx = uvY * uvRowStride + uvX * uvPixelStride;
        final u = uBytes[uvIdx] & 0xff;
        final v = vBytes[uvIdx] & 0xff;

        final pi = oy * outSize + ox;
        out[pi] = (yVal + 1.402 * (v - 128)).clamp(0, 255) / 255.0;
        out[stride + pi] = (yVal - 0.344 * (u - 128) - 0.714 * (v - 128)).clamp(0, 255) / 255.0;
        out[2 * stride + pi] = (yVal + 1.772 * (u - 128)).clamp(0, 255) / 255.0;
      }
    }
  } else {
    for (var oy = 0; oy < outSize; oy++) {
      final srcY = (oy * height) ~/ outSize;
      for (var ox = 0; ox < outSize; ox++) {
        final srcX = (ox * width) ~/ outSize;

        final yIdx = srcY * yRowStride + srcX;
        final yVal = yBytes[yIdx] & 0xff;
        final uvY = srcY >> 1;
        final uvX = srcX >> 1;
        final uvIdx = uvY * uvRowStride + uvX * uvPixelStride;
        final u = uBytes[uvIdx] & 0xff;
        final v = vBytes[uvIdx] & 0xff;

        final pi = oy * outSize + ox;
        out[pi] = (yVal + 1.402 * (v - 128)).clamp(0, 255) / 255.0;
        out[stride + pi] = (yVal - 0.344 * (u - 128) - 0.714 * (v - 128)).clamp(0, 255) / 255.0;
        out[2 * stride + pi] = (yVal + 1.772 * (u - 128)).clamp(0, 255) / 255.0;
      }
    }
  }
}

class _PerfOverlay extends StatelessWidget {
  const _PerfOverlay({
    required this.preprocessMs,
    required this.inferenceMs,
    required this.decodeMs,
    required this.totalMs,
  });

  final int preprocessMs;
  final int inferenceMs;
  final int decodeMs;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Realtime metrics'),
            Text('pre: ${preprocessMs}ms'),
            Text('infer: ${inferenceMs}ms'),
            Text('decode: ${decodeMs}ms'),
            Text('total: ${totalMs}ms'),
          ],
        ),
      ),
    );
  }
}
