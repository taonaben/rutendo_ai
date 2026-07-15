import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rutendo_ai/features/audio/audio_engine.dart';

import '../models/cue_decision.dart';
import '../models/detection_result.dart';
import '../models/motion_object.dart';
import '../services/calibration_codec.dart';
import '../services/calibration_harness_store.dart';
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
  static const Duration _logInterval = Duration(milliseconds: 500);
  static const Duration _persistInterval = Duration(milliseconds: 250);

  final _onnxService = OnnxInferenceService();
  final CalibrationHarnessStore? _calibrationStore = _createCalibrationStore();
  final _audioEngine = AudioEngine(backend: createDefaultAudioBackend());
  final List<String> _detectionLog = [];
  List<DetectionResult> _liveDetections = const [];
  List<MotionObject> _liveMotionObjects = const [];
  RiskAssessment _assessment = const RiskAssessment(
    hazards: [],
    audioCue: AudioCueDecision(pattern: AudioCuePattern.none, intervalMs: 0),
    hapticCue: HapticCueDecision(pattern: HapticCuePattern.none, durationMs: 0),
  );
  int _detectionCounter = 0;
  DateTime _lastLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPersistAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _userIsMoving = true;
  bool _isRecording = false;
  bool _isReplaying = false;
  int? _activeSessionId;
  int _persistedFrameCount = 0;
  String _statusText = 'Idle';

  static bool get _isWidgetTest {
    final binding = WidgetsBinding.instance;
    return binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  static CalibrationHarnessStore? _createCalibrationStore() {
    if (kIsWeb || _isWidgetTest) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => CalibrationHarnessStore(),
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    if (!_isWidgetTest) {
      _onnxService.load().catchError((_) {});
    }
  }

  void _onLiveDetections(List<DetectionResult> detections) {
    if (!mounted) return;
    if (_isReplaying) return;
    final now = DateTime.now();
    final shouldAppendLogs = now.difference(_lastLogAt) >= _logInterval;

    setState(() {
      _liveDetections = detections;
      if (_liveMotionObjects.isEmpty) {
        _assessment = _riskEngine.assess(detections);
        _audioEngine.updateFromAssessment(_assessment);
      }

      if (shouldAppendLogs) {
        _lastLogAt = now;
        for (final d in detections) {
          _detectionCounter++;
          final x1 = (d.left * 640).round();
          final y1 = (d.top * 640).round();
          final x2 = (d.right * 640).round();
          final y2 = (d.bottom * 640).round();
          _detectionLog.insert(
            0,
            '{"id":"det_${_detectionCounter.toString().padLeft(5, '0')}",'
            '"label":"${d.label}",'
            '"confidence":${d.confidence.toStringAsFixed(2)},'
            '"box":{"x1":$x1,"y1":$y1,"x2":$x2,"y2":$y2},'
            '"frame":{"width":640,"height":640}}',
          );
        }
      }

      while (_detectionLog.length > 50) _detectionLog.removeLast();
    });
  }

  void _onMotionObjects(List<MotionObject> motionObjects) {
    if (!mounted) return;
    if (_isReplaying) return;

    setState(() {
      _liveMotionObjects = motionObjects;
      _assessment = _riskEngine.assessMotion(
        motionObjects,
        userIsMoving: _userIsMoving,
      );
    });
    _audioEngine.updateFromAssessment(_assessment);

    final shouldPersist =
        _isRecording &&
        _activeSessionId != null &&
        DateTime.now().difference(_lastPersistAt) >= _persistInterval;
    if (shouldPersist) {
      final store = _calibrationStore;
      if (store == null) {
        return;
      }

      final sessionId = _activeSessionId;
      if (sessionId != null) {
        _lastPersistAt = DateTime.now();
        unawaited(
          store
              .appendFrame(
                sessionId: sessionId,
                timestampMs: _lastPersistAt.millisecondsSinceEpoch,
                detections: _liveDetections,
                motionObjects: motionObjects,
                riskAssessment: _assessment,
              )
              .then((_) {
                if (!mounted) return;
                setState(() {
                  _persistedFrameCount += 1;
                });
              }),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final store = _calibrationStore;
    if (store == null) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Capture unavailable on this platform';
      });
      return;
    }

    final sessionId = await store.startSession(
      mode: 'live',
      notes: 'risk_engine_demo',
    );
    if (!mounted) return;
    setState(() {
      _activeSessionId = sessionId;
      _isRecording = true;
      _persistedFrameCount = 0;
      _statusText = 'Recording session #$sessionId';
    });
  }

  Future<void> _stopRecording() async {
    final store = _calibrationStore;
    if (store == null) return;

    final sessionId = _activeSessionId;
    if (!_isRecording || sessionId == null) return;
    await store.endSession(sessionId);
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _activeSessionId = null;
      _statusText = 'Saved session #$sessionId ($_persistedFrameCount frames)';
    });
  }

  Future<void> _replayLatestSession() async {
    final store = _calibrationStore;
    if (store == null) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Replay unavailable on this platform';
      });
      return;
    }

    if (_isReplaying) return;
    if (_isRecording) {
      await _stopRecording();
    }

    final latestSession = await store.latestCompletedSession();
    if (latestSession == null) {
      if (!mounted) return;
      setState(() {
        _statusText = 'No saved sessions to replay';
      });
      return;
    }

    final frames = await store.framesForSession(latestSession.id);
    if (frames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Session #${latestSession.id} has no frames';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isReplaying = true;
      _statusText =
          'Replaying session #${latestSession.id} (${frames.length} frames)';
    });

    var previousTimestamp = frames.first.timestampMs;
    for (final frame in frames) {
      if (!mounted) return;

      final detections = CalibrationCodec.detectionsFromJson(
        frame.detectionsJson,
      );
      final motionObjects = CalibrationCodec.motionObjectsFromJson(
        frame.motionObjectsJson,
      );
      final assessment = _riskEngine.assessMotion(
        motionObjects,
        userIsMoving: _userIsMoving,
      );

      setState(() {
        _liveDetections = detections;
        _liveMotionObjects = motionObjects;
        _assessment = assessment;
      });
      _audioEngine.updateFromAssessment(_assessment);

      final deltaMs = frame.timestampMs - previousTimestamp;
      previousTimestamp = frame.timestampMs;
      final stepDelayMs = deltaMs.clamp(40, 220);
      await Future.delayed(Duration(milliseconds: stepDelayMs));
    }

    if (!mounted) return;
    setState(() {
      _isReplaying = false;
      _statusText = 'Replay complete for session #${latestSession.id}';
    });
    _audioEngine.updateFromAssessment(_assessment);
  }

  @override
  void dispose() {
    final store = _calibrationStore;
    final sessionId = _activeSessionId;
    if (sessionId != null && store != null) {
      unawaited(store.endSession(sessionId));
    }
    if (store != null) {
      unawaited(store.close());
    }
    _audioEngine.dispose();
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
              onMotionObjects: _onMotionObjects,
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
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
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${_liveDetections.length} obj(s)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                      children: [
                        ElevatedButton(
                          onPressed:
                              _isReplaying
                                  ? null
                                  : (_isRecording
                                      ? _stopRecording
                                      : _startRecording),
                          child: Text(
                            _isRecording ? 'Stop Capture' : 'Start Capture',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isReplaying ? null : _replayLatestSession,
                          child: const Text('Replay Latest'),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Moving',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Switch(
                          value: _userIsMoving,
                          onChanged:
                              _isReplaying
                                  ? null
                                  : (value) {
                                    setState(() {
                                      _userIsMoving = value;
                                    });
                                  },
                        ),
                      ],
                    ),
                      ),
                    Text(
                      'status=$_statusText  savedFrames=$_persistedFrameCount',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'risk=${_assessment.primaryHazard?.severity.name ?? 'none'}  motion=${_liveMotionObjects.length}',
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 12,
                      ),
                    ),
                    if (_liveDetections.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _liveDetections
                            .take(5)
                            .map(
                              (d) =>
                                  '${d.label} ${(d.confidence * 100).round()}%',
                            )
                            .join('  |  '),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 16),
                    SizedBox(
                      height: 120,
                      child:
                          _detectionLog.isEmpty
                              ? const Text(
                                'No detections yet',
                                style: TextStyle(color: Colors.white38),
                              )
                              : ListView.builder(
                                itemCount: _detectionLog.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      _detectionLog[index],
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
