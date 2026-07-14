import 'package:flutter_test/flutter_test.dart';
import 'package:rutendo_ai/features/audio/audio_engine.dart';
import 'package:rutendo_ai/features/safety/models/cue_decision.dart';
import 'package:rutendo_ai/features/safety/models/detection_result.dart';
import 'package:rutendo_ai/features/safety/models/hazard.dart';

void main() {
  const mapper = AudioCueMapper();

  Hazard hazard({
    required String label,
    required double centerX,
    required HazardSeverity severity,
    double? ttc,
    double? distanceMeters,
    bool ttcOverride = false,
  }) {
    final width = 0.2;
    final left = (centerX - width / 2).clamp(0.0, 1.0);
    final right = (centerX + width / 2).clamp(0.0, 1.0);
    return Hazard(
      detection: DetectionResult(
        label: label,
        confidence: 0.9,
        left: left,
        top: 0.2,
        right: right,
        bottom: 0.8,
      ),
      zone:
          centerX < 0.33
              ? DetectionZone.left
              : (centerX > 0.66 ? DetectionZone.right : DetectionZone.center),
      distance: EstimatedDistance.medium,
      severity: severity,
      score: 80,
      reason: 'test',
      trackId: 1,
      estimatedDistanceMeters: distanceMeters,
      timeToCollisionSeconds: ttc,
      ttcOverrideApplied: ttcOverride,
    );
  }

  test('direction maps continuously to pan extremes and center', () {
    expect(mapper.angleToPan(-33, 66), closeTo(-1.0, 0.0001));
    expect(mapper.angleToPan(0, 66), closeTo(0.0, 0.0001));
    expect(mapper.angleToPan(33, 66), closeTo(1.0, 0.0001));
  });

  test('urgency interval decreases as TTC decreases', () {
    final safe = mapper.urgencyIntervalMs(
      hazard(
        label: 'person',
        centerX: 0.5,
        severity: HazardSeverity.medium,
        ttc: 6.0,
      ),
    );
    final urgent = mapper.urgencyIntervalMs(
      hazard(
        label: 'person',
        centerX: 0.5,
        severity: HazardSeverity.medium,
        ttc: 1.0,
      ),
    );

    expect(urgent, lessThan(safe));
  });

  test('hazard type maps to distinct cue families', () {
    final staticHazard = hazard(
      label: 'chair',
      centerX: 0.5,
      severity: HazardSeverity.medium,
    );
    final dynamicHazard = hazard(
      label: 'person',
      centerX: 0.5,
      severity: HazardSeverity.medium,
    );
    final criticalHazard = hazard(
      label: 'person',
      centerX: 0.5,
      severity: HazardSeverity.critical,
      ttcOverride: true,
    );

    expect(mapper.cueFamily(staticHazard), AudioCueFamily.staticObstacle);
    expect(mapper.cueFamily(dynamicHazard), AudioCueFamily.dynamicObject);
    expect(mapper.cueFamily(criticalHazard), AudioCueFamily.critical);
  });

  test('assessment mapping returns null when there is no hazard', () {
    const assessment = RiskAssessment(
      hazards: [],
      audioCue: AudioCueDecision(pattern: AudioCuePattern.none, intervalMs: 0),
      hapticCue: HapticCueDecision(
        pattern: HapticCuePattern.none,
        durationMs: 0,
      ),
    );

    expect(mapper.fromAssessment(assessment), isNull);
  });
}
