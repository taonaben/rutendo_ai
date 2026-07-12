import 'dart:async';
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
  List<DetectionResult> _detections = const [];
  int _lastProcessed = 0;
  Size? _sensorSize;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startCamera);
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
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isProcessing || now - _lastProcessed < 1000) return;
    _isProcessing = true;
    _lastProcessed = now;

    if (_sensorSize == null && mounted) {
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      setState(() {
        _sensorSize = w > h ? Size(h, w) : Size(w, h);
      });
    }

    unawaited(_processFrame(image));
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final rgba = _yuv420ToRgba(image);
      final src = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: rgba.buffer,
        numChannels: 4,
      );
      final upright = image.width > image.height
          ? img.copyRotate(src, angle: 90)
          : src;
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

  Uint8List _yuv420ToRgba(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final yRowStride = image.planes[0].bytesPerRow;
    final rgba = Uint8List(width * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIdx = y * yRowStride + x;
        final yVal = image.planes[0].bytes[yIdx] & 0xff;
        final uvY = y >> 1;
        final uvX = x >> 1;
        final uvIdx = uvY * uvRowStride + uvX * uvPixelStride;
        final u = image.planes[1].bytes[uvIdx] & 0xff;
        final v = image.planes[2].bytes[uvIdx] & 0xff;

        final r = _clamp(yVal + 1.402 * (v - 128));
        final g = _clamp(yVal - 0.344 * (u - 128) - 0.714 * (v - 128));
        final b = _clamp(yVal + 1.772 * (u - 128));

        final dstIdx = (y * width + x) * 4;
        rgba[dstIdx] = r;
        rgba[dstIdx + 1] = g;
        rgba[dstIdx + 2] = b;
        rgba[dstIdx + 3] = 255;
      }
    }

    return rgba;
  }

  int _clamp(num v) => v.clamp(0, 255).toInt();

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() { _status = status; });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
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

    // FittedBox.cover scale from camera preview to this area
    final scale = (sw / pw) > (sh / ph) ? (sw / pw) : (sh / ph);
    final visibleW = sw / scale;
    final visibleH = sh / scale;
    final cropX = (pw - visibleW) / 2;
    final cropY = (ph - visibleH) / 2;

    for (final d in detections) {
      // Model output is in 640x640 of the upright (portrait) image.
      // Map to portrait camera sensor coords (no rotation needed).
      final camX = d.left * pw;
      final camY = d.top * ph;
      final camR = d.right * pw;
      final camB = d.bottom * ph;
      final camW = camR - camX;
      final camH = camB - camY;

      // FittedBox.cover crop and scale to screen
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
        Rect.fromLTWH(
            visX, visY - tp.height - 4, tp.width + 6, tp.height + 4),
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
