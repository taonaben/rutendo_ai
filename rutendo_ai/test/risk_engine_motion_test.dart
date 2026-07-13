import 'package:flutter_test/flutter_test.dart';
import 'package:rutendo_ai/features/safety/models/cue_decision.dart';
import 'package:rutendo_ai/features/safety/models/detection_result.dart';
import 'package:rutendo_ai/features/safety/models/hazard.dart';
import 'package:rutendo_ai/features/safety/models/motion_object.dart';
import 'package:rutendo_ai/features/safety/models/tracked_object.dart';
import 'package:rutendo_ai/features/safety/services/risk_engine.dart';

void main() {
  const engine = RiskEngine(ttcEmergencyThresholdSeconds: 1.5);

  MotionObject motion({
    required int trackId,
    required String label,
    required double confidence,
    required double left,
    required double top,
    required double right,
    required double bottom,
    required bool approaching,
    required double? closingSpeed,
    required double? ttc,
    required double? distanceMeters,
  }) {
    final detection = DetectionResult(
      label: label,
      confidence: confidence,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );

    final tracked = TrackedObject(
      trackId: trackId,
      detection: detection,
      firstSeenTimestampMs: 1000,
      lastSeenTimestampMs: 1200,
      seenFrames: 4,
      missedFrames: 0,
    );

    return MotionObject(
      trackedObject: tracked,
      dtMs: 200,
      velocityXPerSecond: 0,
      velocityYPerSecond: 0,
      areaGrowthPerSecond: 0,
      estimatedDistanceMeters: distanceMeters,
      distanceReliable: distanceMeters != null,
      approaching: approaching,
      closingSpeedMetersPerSecond: closingSpeed,
      timeToCollisionSeconds: ttc,
    );
  }

  test('applies TTC emergency override even when user is stationary', () {
    final assessment = engine.assessMotion([
      motion(
        trackId: 1,
        label: 'person',
        confidence: 0.62,
        left: 0.44,
        top: 0.15,
        right: 0.56,
        bottom: 0.40,
        approaching: true,
        closingSpeed: 1.7,
        ttc: 1.0,
        distanceMeters: 2.1,
      ),
    ], userIsMoving: false);

    expect(assessment.hazards, hasLength(1));
    final hazard = assessment.hazards.first;
    expect(hazard.severity, HazardSeverity.critical);
    expect(hazard.ttcOverrideApplied, isTrue);
    expect(hazard.suppressedByStationaryUser, isFalse);
    expect(assessment.audioCue.pattern, AudioCuePattern.urgentPulse);
  });

  test('suppresses non-emergency hazards when user is stationary', () {
    final assessment = engine.assessMotion([
      motion(
        trackId: 2,
        label: 'person',
        confidence: 0.91,
        left: 0.42,
        top: 0.22,
        right: 0.58,
        bottom: 0.92,
        approaching: false,
        closingSpeed: 0.0,
        ttc: null,
        distanceMeters: 1.8,
      ),
    ], userIsMoving: false);

    expect(assessment.hazards, isEmpty);
    expect(assessment.audioCue.pattern, AudioCuePattern.none);
    expect(assessment.hapticCue.pattern, HapticCuePattern.none);
  });

  test('returns top hazards sorted by weighted motion-aware score', () {
    final assessment = engine.assessMotion([
      motion(
        trackId: 3,
        label: 'person',
        confidence: 0.85,
        left: 0.08,
        top: 0.25,
        right: 0.28,
        bottom: 0.70,
        approaching: true,
        closingSpeed: 0.9,
        ttc: 3.0,
        distanceMeters: 2.3,
      ),
      motion(
        trackId: 4,
        label: 'car',
        confidence: 0.80,
        left: 0.40,
        top: 0.18,
        right: 0.62,
        bottom: 0.78,
        approaching: true,
        closingSpeed: 1.2,
        ttc: 2.1,
        distanceMeters: 1.4,
      ),
      motion(
        trackId: 5,
        label: 'chair',
        confidence: 0.82,
        left: 0.72,
        top: 0.05,
        right: 0.90,
        bottom: 0.30,
        approaching: false,
        closingSpeed: 0,
        ttc: null,
        distanceMeters: 4.8,
      ),
    ], userIsMoving: true);

    expect(assessment.hazards, hasLength(2));
    expect(assessment.hazards.first.trackId, 4);
    expect(
      assessment.hazards.first.severity.index,
      greaterThanOrEqualTo(HazardSeverity.high.index),
    );
    expect(
      assessment.hazards.first.scoreBreakdown['closingSpeed'],
      greaterThan(0),
    );
  });
}
