import 'package:flutter_test/flutter_test.dart';
import 'package:rutendo_ai/features/safety/models/cue_decision.dart';
import 'package:rutendo_ai/features/safety/models/detection_result.dart';
import 'package:rutendo_ai/features/safety/models/hazard.dart';
import 'package:rutendo_ai/features/safety/services/risk_engine.dart';

void main() {
  const engine = RiskEngine();

  DetectionResult detection({
    required String label,
    required double confidence,
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return DetectionResult(
      label: label,
      confidence: confidence,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  test('prioritizes a near center obstacle as the primary hazard', () {
    final assessment = engine.assess([
      detection(
        label: 'chair',
        confidence: 0.86,
        left: 0.40,
        top: 0.20,
        right: 0.60,
        bottom: 0.96,
      ),
      detection(
        label: 'person',
        confidence: 0.91,
        left: 0.04,
        top: 0.25,
        right: 0.24,
        bottom: 0.70,
      ),
    ]);

    expect(assessment.hazards, hasLength(2));
    expect(assessment.primaryHazard?.detection.label, 'chair');
    expect(assessment.primaryHazard?.zone, DetectionZone.center);
    expect(assessment.primaryHazard?.distance, EstimatedDistance.near);
    expect(assessment.primaryHazard?.severity, HazardSeverity.high);
    expect(assessment.audioCue.pattern, AudioCuePattern.fastBeep);
    expect(assessment.audioCue.zone, DetectionZone.center);
    expect(assessment.hapticCue.pattern, HapticCuePattern.strongPulse);
  });

  test('ignores far non-vehicle detections to reduce audio overload', () {
    final assessment = engine.assess([
      detection(
        label: 'bench',
        confidence: 0.92,
        left: 0.37,
        top: 0.10,
        right: 0.56,
        bottom: 0.35,
      ),
    ]);

    expect(assessment.hazards, isEmpty);
    expect(assessment.audioCue.pattern, AudioCuePattern.none);
    expect(assessment.hapticCue.pattern, HapticCuePattern.none);
  });

  test('alerts strongly for a medium-distance vehicle', () {
    final assessment = engine.assess([
      detection(
        label: 'car',
        confidence: 0.81,
        left: 0.68,
        top: 0.30,
        right: 0.94,
        bottom: 0.75,
      ),
    ]);

    expect(assessment.primaryHazard?.detection.label, 'car');
    expect(assessment.primaryHazard?.zone, DetectionZone.right);
    expect(assessment.primaryHazard?.distance, EstimatedDistance.medium);
    expect(assessment.primaryHazard?.severity, HazardSeverity.high);
    expect(assessment.audioCue.pattern, AudioCuePattern.fastBeep);
    expect(assessment.audioCue.zone, DetectionZone.right);
  });

  test('returns only the top two hazards', () {
    final assessment = engine.assess([
      detection(
        label: 'person',
        confidence: 0.88,
        left: 0.40,
        top: 0.20,
        right: 0.60,
        bottom: 0.95,
      ),
      detection(
        label: 'car',
        confidence: 0.74,
        left: 0.68,
        top: 0.28,
        right: 0.96,
        bottom: 0.77,
      ),
      detection(
        label: 'chair',
        confidence: 0.90,
        left: 0.05,
        top: 0.20,
        right: 0.30,
        bottom: 0.82,
      ),
    ]);

    expect(assessment.hazards, hasLength(2));
    expect(
      assessment.hazards.map((hazard) => hazard.detection.label),
      isNot(contains('chair')),
    );
  });
}
