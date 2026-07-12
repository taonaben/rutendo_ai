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
  });

  final DetectionResult detection;
  final DetectionZone zone;
  final EstimatedDistance distance;
  final HazardSeverity severity;
  final double score;
  final String reason;

  bool get shouldAlert => severity != HazardSeverity.ignore;
}
