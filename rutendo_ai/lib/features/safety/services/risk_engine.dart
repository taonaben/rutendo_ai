import '../models/cue_decision.dart';
import '../models/detection_result.dart';
import '../models/hazard.dart';

class RiskEngine {
  const RiskEngine({
    this.minimumConfidence = 0.45,
    this.maxAlerts = 2,
  });

  final double minimumConfidence;
  final int maxAlerts;

  static const Set<String> vehicleLabels = {
    'bicycle',
    'bus',
    'car',
    'motorbike',
    'motorcycle',
    'truck',
    'train',
  };

  RiskAssessment assess(List<DetectionResult> detections) {
    final hazards =
        detections
            .where((detection) => detection.confidence >= minimumConfidence)
            .map(_scoreDetection)
            .where((hazard) => hazard.shouldAlert)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final selectedHazards = hazards.take(maxAlerts).toList(growable: false);
    final primaryHazard =
        selectedHazards.isEmpty ? null : selectedHazards.first;

    return RiskAssessment(
      hazards: selectedHazards,
      audioCue: _audioCueFor(primaryHazard),
      hapticCue: _hapticCueFor(primaryHazard),
    );
  }

  Hazard _scoreDetection(DetectionResult detection) {
    final zone = detection.zone;
    final distance = detection.estimatedDistance;
    final isVehicle = vehicleLabels.contains(detection.label.toLowerCase());

    var score = detection.confidence * 10;
    var reason = 'Low priority object outside the immediate walking path';

    switch (distance) {
      case EstimatedDistance.near:
        score += 45;
      case EstimatedDistance.medium:
        score += 24;
      case EstimatedDistance.far:
        score += 4;
    }

    switch (zone) {
      case DetectionZone.center:
        score += 32;
      case DetectionZone.left:
      case DetectionZone.right:
        score += 14;
    }

    if (isVehicle) {
      score += 24;
    }

    if (distance == EstimatedDistance.far && !isVehicle) {
      return Hazard(
        detection: detection,
        zone: zone,
        distance: distance,
        severity: HazardSeverity.ignore,
        score: score,
        reason: 'Far non-vehicle object ignored to avoid audio overload',
      );
    }

    final severity = _severityFor(score);
    if (isVehicle && distance != EstimatedDistance.far) {
      reason = 'Vehicle detected close enough to need a strong warning';
    } else if (zone == DetectionZone.center &&
        distance == EstimatedDistance.near) {
      reason = 'Near object in the direct walking path';
    } else if (distance == EstimatedDistance.near) {
      reason = 'Near object to the ${zone.name} side';
    } else if (zone == DetectionZone.center &&
        distance == EstimatedDistance.medium) {
      reason = 'Medium-distance object in the direct walking path';
    }

    return Hazard(
      detection: detection,
      zone: zone,
      distance: distance,
      severity: severity,
      score: score,
      reason: reason,
    );
  }

  HazardSeverity _severityFor(double score) {
    if (score >= 95) {
      return HazardSeverity.critical;
    }
    if (score >= 75) {
      return HazardSeverity.high;
    }
    if (score >= 55) {
      return HazardSeverity.medium;
    }
    if (score >= 35) {
      return HazardSeverity.low;
    }
    return HazardSeverity.ignore;
  }

  AudioCueDecision _audioCueFor(Hazard? hazard) {
    if (hazard == null) {
      return const AudioCueDecision(
        pattern: AudioCuePattern.none,
        intervalMs: 0,
      );
    }

    return switch (hazard.severity) {
      HazardSeverity.critical => AudioCueDecision(
        pattern: AudioCuePattern.urgentPulse,
        zone: hazard.zone,
        intervalMs: 150,
      ),
      HazardSeverity.high => AudioCueDecision(
        pattern: AudioCuePattern.fastBeep,
        zone: hazard.zone,
        intervalMs: 250,
      ),
      HazardSeverity.medium => AudioCueDecision(
        pattern: AudioCuePattern.mediumBeep,
        zone: hazard.zone,
        intervalMs: 500,
      ),
      HazardSeverity.low => AudioCueDecision(
        pattern: AudioCuePattern.slowBeep,
        zone: hazard.zone,
        intervalMs: 900,
      ),
      HazardSeverity.ignore => const AudioCueDecision(
        pattern: AudioCuePattern.none,
        intervalMs: 0,
      ),
    };
  }

  HapticCueDecision _hapticCueFor(Hazard? hazard) {
    if (hazard == null) {
      return const HapticCueDecision(
        pattern: HapticCuePattern.none,
        durationMs: 0,
      );
    }

    return switch (hazard.severity) {
      HazardSeverity.critical => const HapticCueDecision(
        pattern: HapticCuePattern.strongPulse,
        durationMs: 450,
      ),
      HazardSeverity.high => const HapticCueDecision(
        pattern: HapticCuePattern.strongPulse,
        durationMs: 300,
      ),
      HazardSeverity.medium => const HapticCueDecision(
        pattern: HapticCuePattern.mediumPulse,
        durationMs: 180,
      ),
      HazardSeverity.low => const HapticCueDecision(
        pattern: HapticCuePattern.lightPulse,
        durationMs: 100,
      ),
      HazardSeverity.ignore => const HapticCueDecision(
        pattern: HapticCuePattern.none,
        durationMs: 0,
      ),
    };
  }
}
