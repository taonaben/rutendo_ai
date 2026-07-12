import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/detection_result.dart';
import '../services/onnx_inference_service.dart';
import '../services/yolo_decoder.dart';

class CameraPreviewPanel extends StatefulWidget {
  const CameraPreviewPanel({
    required this.onnxService,
    required this.onDetections,
    super.key,
  });

  final OnnxInferenceService onnxService;
  final void Function(List<DetectionResult> detections) onDetections;

  @override
  State<CameraPreviewPanel> createState() => _CameraPreviewPanelState();
}

class _CameraPreviewPanelState extends State<CameraPreviewPanel> {
  CameraController? _controller;
  String _status = 'Starting camera...';
  bool _isProcessing = false;
  bool _workerBusy = false;
  List<DetectionResult> _detections = const [];
  Size? _sensorSize;

  Isolate? _workerIsolate;
  SendPort? _commandPort;
  ReceivePort _workerResponsePort = ReceivePort();
  bool _workerReady = false;

  @override
  void initState() {
    super.initState();
    _initWorker();
    Future.microtask(_startCamera);
  }

  void _initWorker() {
    _workerResponsePort.listen(_onWorkerMessage);
    Isolate.spawn(_workerEntry, _workerResponsePort.sendPort);
  }

  void _onWorkerMessage(dynamic message) {
    if (!mounted) return;

    if (message is SendPort) {
      _commandPort = message;
      _workerReady = true;
      return;
    }

    if (message is Float32List) {
      _workerBusy = false;
      _runInference(message);
    }
  }

  Future<void> _runInference(Float32List floatData) async {
    try {
      final outputs = await widget.onnxService.runRaw(
        inputName: 'images',
        input: floatData,
        inputShape: [1, 3, 640, 640],
      );

      if (outputs.isNotEmpty && outputs[0] != null) {
        final raw = outputs[0]!.value;
        if (raw == null) return;

        final detections = decodeYolo(
          rawOutput: raw as Object,
          labels: widget.onnxService.labels,
          confidenceThreshold: 0.35,
        );

        if (mounted) {
          setState(() {
            _detections = detections;
          });
          widget.onDetections(detections);
        }
      }
    } catch (e) {
      debugPrint('[Camera] Error: $e');
    } finally {
      _isProcessing = false;
    }
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
    if (!_workerReady) return;
    if (_isProcessing || _workerBusy) return;
    _isProcessing = true;
    _workerBusy = true;

    if (_sensorSize == null && mounted) {
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      setState(() {
        _sensorSize = w > h ? Size(h, w) : Size(w, h);
      });
    }

    final yBytes = Uint8List.fromList(image.planes[0].bytes);
    final uBytes = Uint8List.fromList(image.planes[1].bytes);
    final vBytes = Uint8List.fromList(image.planes[2].bytes);
    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final w = image.width;
    final h = image.height;
    final needsRotate = w > h;

    _commandPort?.send(<dynamic>[
      w, h, yBytes, uBytes, vBytes,
      yRowStride, uvRowStride, uvPixelStride, needsRotate,
    ]);
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() { _status = status; });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
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
                        width: controller!.value.previewSize?.height ?? 720,
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
                ],
              )
            : Center(
                child: Text(_status,
                    style: const TextStyle(color: Colors.white54)),
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

      final paint = Paint()
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
  bool shouldRepaint(_BoundingBoxPainter old) =>
      old.detections != detections;

  Color _colorForLabel(String label) {
    const colors = [
      Colors.red, Colors.blue, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.amber,
      Colors.cyan, Colors.lime,
    ];
    return colors[label.hashCode % colors.length];
  }
}

// ---- Long-lived background worker ----

@pragma('vm:entry-point')
void _workerEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is List<dynamic> && message.length >= 9) {
      try {
        final floatData = _preprocessFromList(message);
        mainSendPort.send(floatData);
      } catch (e) {
        // Silently drop errored frames
      }
    }
  });
}

Float32List _preprocessFromList(List<dynamic> args) {
  return _preprocessFrame(
    width: args[0] as int,
    height: args[1] as int,
    yBytes: args[2] as Uint8List,
    uBytes: args[3] as Uint8List,
    vBytes: args[4] as Uint8List,
    yRowStride: args[5] as int,
    uvRowStride: args[6] as int,
    uvPixelStride: args[7] as int,
    needsRotate: args[8] as bool,
  );
}

Float32List _preprocessFrame({
  required int width,
  required int height,
  required Uint8List yBytes,
  required Uint8List uBytes,
  required Uint8List vBytes,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required bool needsRotate,
}) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yIdx = y * yRowStride + x;
      final yVal = yBytes[yIdx] & 0xff;
      final uvY = y >> 1;
      final uvX = x >> 1;
      final uvIdx = uvY * uvRowStride + uvX * uvPixelStride;
      final u = uBytes[uvIdx] & 0xff;
      final v = vBytes[uvIdx] & 0xff;

      final r = (yVal + 1.402 * (v - 128)).clamp(0, 255).toInt();
      final g = (yVal - 0.344 * (u - 128) - 0.714 * (v - 128)).clamp(0, 255).toInt();
      final b = (yVal + 1.772 * (u - 128)).clamp(0, 255).toInt();

      final dstIdx = (y * width + x) * 4;
      rgba[dstIdx] = r;
      rgba[dstIdx + 1] = g;
      rgba[dstIdx + 2] = b;
      rgba[dstIdx + 3] = 255;
    }
  }

  final src = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  final upright = needsRotate ? img.copyRotate(src, angle: 90) : src;
  final resized = img.copyResize(upright, width: 640, height: 640);

  final floatData = Float32List(1 * 3 * 640 * 640);
  for (var y = 0; y < 640; y++) {
    for (var x = 0; x < 640; x++) {
      final pixel = resized.getPixel(x, y);
      final idx = y * 640 + x;
      floatData[0 * 640 * 640 + idx] = pixel.r / 255.0;
      floatData[1 * 640 * 640 + idx] = pixel.g / 255.0;
      floatData[2 * 640 * 640 + idx] = pixel.b / 255.0;
    }
  }

  return floatData;
}
