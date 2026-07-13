import 'detection_result.dart';

enum HazardSeverity { ignore, low, medium, high, critical }

class Hazard {
  const Hazard({
    required this.detection,
    required this.zone,
    required this.distance,
    required this.severity,
    required this.score,
    required this.reason,
    this.trackId,
    this.estimatedDistanceMeters,
    this.timeToCollisionSeconds,
    this.ttcOverrideApplied = false,
    this.suppressedByStationaryUser = false,
    this.scoreBreakdown = const {},
  });

  final DetectionResult detection;
  final DetectionZone zone;
  final EstimatedDistance distance;
  final HazardSeverity severity;
  final double score;
  final String reason;
  final int? trackId;
  final double? estimatedDistanceMeters;
  final double? timeToCollisionSeconds;
  final bool ttcOverrideApplied;
  final bool suppressedByStationaryUser;
  final Map<String, double> scoreBreakdown;

  bool get shouldAlert => severity != HazardSeverity.ignore;
}
