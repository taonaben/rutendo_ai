import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewPanel extends StatefulWidget {
  const CameraPreviewPanel({super.key});

  @override
  State<CameraPreviewPanel> createState() => _CameraPreviewPanelState();
}

class _CameraPreviewPanelState extends State<CameraPreviewPanel> {
  CameraController? _controller;
  String _status = 'Not started';
  bool _isStarting = false;

  Future<void> _startCamera() async {
    setState(() {
      _isStarting = true;
      _status = 'Requesting camera...';
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setStatus('No camera found on this device');
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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller?.dispose();
      _controller = controller;
      await controller.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Camera ready: ${backCamera.name}';
      });
    } on CameraException catch (error) {
      _setStatus('Camera error: ${error.code}');
    } catch (error) {
      _setStatus('Camera error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  void _setStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Camera Preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton(
                  onPressed: _isStarting ? null : _startCamera,
                  child: Text(_isStarting ? 'Starting...' : 'Start camera'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Status', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(_status),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ColoredBox(
                  color: Colors.black,
                  child: isReady
                      ? CameraPreview(controller)
                      : const Center(
                          child: Text(
                            'Camera preview will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
