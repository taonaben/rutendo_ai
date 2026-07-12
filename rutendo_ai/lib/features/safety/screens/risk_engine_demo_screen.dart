import 'package:flutter/material.dart';

import '../models/cue_decision.dart';
import '../models/detection_result.dart';
import '../models/hazard.dart';
import '../services/onnx_inference_service.dart';
import '../services/risk_engine.dart';
import '../widgets/camera_preview_panel.dart';

class RiskEngineDemoScreen extends StatefulWidget {
  const RiskEngineDemoScreen({super.key});

  @override
  State<RiskEngineDemoScreen> createState() => _RiskEngineDemoScreenState();
}

class _RiskEngineDemoScreenState extends State<RiskEngineDemoScreen> {
  static const _riskEngine = RiskEngine();

  final _onnxService = OnnxInferenceService();
  final List<String> _detectionLog = [];
  List<DetectionResult> _liveDetections = const [];
  RiskAssessment _assessment = _riskEngine.assess(const []);
  int _lastInferenceMs = 0;
  int _detectionCounter = 0;

  @override
  void initState() {
    super.initState();
    _onnxService.load().catchError((_) {});
  }

  void _onLiveDetections(List<DetectionResult> detections) {
    if (!mounted) return;
    setState(() {
      _liveDetections = detections;
      _assessment = _riskEngine.assess(detections);
      for (final d in detections) {
        _detectionCounter++;
        final x1 = (d.left * 640).round();
        final y1 = (d.top * 640).round();
        final x2 = (d.right * 640).round();
        final y2 = (d.bottom * 640).round();
        _detectionLog.insert(0,
            '{"id":"det_${_detectionCounter.toString().padLeft(5, '0')}",'
            '"label":"${d.label}",'
            '"confidence":${d.confidence.toStringAsFixed(2)},'
            '"box":{"x1":$x1,"y1":$y1,"x2":$x2,"y2":$y2},'
            '"frame":{"width":640,"height":640}}');
      }
      while (_detectionLog.length > 50) _detectionLog.removeLast();
    });
  }

  @override
  void dispose() {
    _onnxService.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: CameraPreviewPanel(
              onnxService: _onnxService,
              onDetections: _onLiveDetections,
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _onnxService.isLoaded
                            ? 'Model: YOLO11n (pruned, 11 classes)'
                            : 'Model: loading...',
                        style: const TextStyle(
                            color: Colors.green, fontSize: 12),
                      ),
                      Text(
                        '${_liveDetections.length} obj(s)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  if (_liveDetections.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _liveDetections.take(5).map(
                        (d) => '${d.label} ${(d.confidence * 100).round()}%',
                      ).join('  |  '),
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Divider(color: Colors.white24, height: 16),
                  Expanded(
                    child: _detectionLog.isEmpty
                        ? const Text(
                            'No detections yet',
                            style: TextStyle(color: Colors.white38),
                          )
                        : ListView.builder(
                            itemCount: _detectionLog.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _detectionLog[index],
                                  style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 13,
                                      fontFamily: 'monospace'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
