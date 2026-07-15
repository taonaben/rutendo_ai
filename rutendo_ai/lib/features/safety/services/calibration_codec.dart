import 'dart:convert';

import '../models/cue_decision.dart';
import '../models/detection_result.dart';
import '../models/hazard.dart';
import '../models/motion_object.dart';
import '../models/tracked_object.dart';

class CalibrationCodec {
  const CalibrationCodec._();

  static String detectionsToJson(List<DetectionResult> detections) {
    return jsonEncode(
      detections
          .map(
            (detection) => <String, dynamic>{
              'label': detection.label,
              'confidence': detection.confidence,
              'left': detection.left,
              'top': detection.top,
              'right': detection.right,
              'bottom': detection.bottom,
            },
          )
          .toList(growable: false),
    );
  }

  static List<DetectionResult> detectionsFromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (item) => DetectionResult(
            label: item['label']?.toString() ?? 'unknown',
            confidence: _asDouble(item['confidence']),
            left: _asDouble(item['left']),
            top: _asDouble(item['top']),
            right: _asDouble(item['right']),
            bottom: _asDouble(item['bottom']),
          ),
        )
        .toList(growable: false);
  }

  static String motionObjectsToJson(List<MotionObject> motionObjects) {
    return jsonEncode(
      motionObjects
          .map(
            (motion) => <String, dynamic>{
              'trackId': motion.trackedObject.trackId,
              'firstSeenTimestampMs': motion.trackedObject.firstSeenTimestampMs,
              'lastSeenTimestampMs': motion.trackedObject.lastSeenTimestampMs,
              'seenFrames': motion.trackedObject.seenFrames,
              'missedFrames': motion.trackedObject.missedFrames,
              'detection': {
                'label': motion.trackedObject.detection.label,
                'confidence': motion.trackedObject.detection.confidence,
                'left': motion.trackedObject.detection.left,
                'top': motion.trackedObject.detection.top,
                'right': motion.trackedObject.detection.right,
                'bottom': motion.trackedObject.detection.bottom,
              },
              'dtMs': motion.dtMs,
              'velocityXPerSecond': motion.velocityXPerSecond,
              'velocityYPerSecond': motion.velocityYPerSecond,
              'areaGrowthPerSecond': motion.areaGrowthPerSecond,
              'estimatedDistanceMeters': motion.estimatedDistanceMeters,
              'distanceReliable': motion.distanceReliable,
              'approaching': motion.approaching,
              'closingSpeedMetersPerSecond': motion.closingSpeedMetersPerSecond,
              'timeToCollisionSeconds': motion.timeToCollisionSeconds,
            },
          )
          .toList(growable: false),
    );
  }

  static List<MotionObject> motionObjectsFromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) {
          final detectionMap = item['detection'];
          final parsedDetectionMap =
              detectionMap is Map ? detectionMap : const <String, dynamic>{};

          final detection = DetectionResult(
            label: parsedDetectionMap['label']?.toString() ?? 'unknown',
            confidence: _asDouble(parsedDetectionMap['confidence']),
            left: _asDouble(parsedDetectionMap['left']),
            top: _asDouble(parsedDetectionMap['top']),
            right: _asDouble(parsedDetectionMap['right']),
            bottom: _asDouble(parsedDetectionMap['bottom']),
          );

          final trackedObject = TrackedObject(
            trackId: _asInt(item['trackId']),
            detection: detection,
            firstSeenTimestampMs: _asInt(item['firstSeenTimestampMs']),
            lastSeenTimestampMs: _asInt(item['lastSeenTimestampMs']),
            seenFrames: _asInt(item['seenFrames']),
            missedFrames: _asInt(item['missedFrames']),
          );

          return MotionObject(
            trackedObject: trackedObject,
            dtMs: _asInt(item['dtMs']),
            velocityXPerSecond: _asDouble(item['velocityXPerSecond']),
            velocityYPerSecond: _asDouble(item['velocityYPerSecond']),
            areaGrowthPerSecond: _asDouble(item['areaGrowthPerSecond']),
            estimatedDistanceMeters: _asNullableDouble(
              item['estimatedDistanceMeters'],
            ),
            distanceReliable: _asBool(item['distanceReliable']),
            approaching: _asBool(item['approaching']),
            closingSpeedMetersPerSecond: _asNullableDouble(
              item['closingSpeedMetersPerSecond'],
            ),
            timeToCollisionSeconds: _asNullableDouble(
              item['timeToCollisionSeconds'],
            ),
          );
        })
        .toList(growable: false);
  }

  static String riskAssessmentToJson(RiskAssessment riskAssessment) {
    return jsonEncode({
      'hazards': riskAssessment.hazards
          .map(
            (hazard) => <String, dynamic>{
              'trackId': hazard.trackId,
              'label': hazard.detection.label,
              'score': hazard.score,
              'severity': hazard.severity.name,
              'reason': hazard.reason,
              'zone': hazard.zone.name,
              'distance': hazard.distance.name,
              'estimatedDistanceMeters': hazard.estimatedDistanceMeters,
              'timeToCollisionSeconds': hazard.timeToCollisionSeconds,
              'ttcOverrideApplied': hazard.ttcOverrideApplied,
              'suppressedByStationaryUser': hazard.suppressedByStationaryUser,
              'scoreBreakdown': hazard.scoreBreakdown,
            },
          )
          .toList(growable: false),
      'audioCue': {
        'pattern': riskAssessment.audioCue.pattern.name,
        'zone': riskAssessment.audioCue.zone?.name,
        'intervalMs': riskAssessment.audioCue.intervalMs,
      },
      'hapticCue': {
        'pattern': riskAssessment.hapticCue.pattern.name,
        'durationMs': riskAssessment.hapticCue.durationMs,
      },
    });
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }
}
