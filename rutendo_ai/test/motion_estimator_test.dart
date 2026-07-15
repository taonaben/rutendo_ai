import 'package:flutter_test/flutter_test.dart';
import 'package:rutendo_ai/features/safety/models/detection_result.dart';
import 'package:rutendo_ai/features/safety/models/tracked_object.dart';
import 'package:rutendo_ai/features/safety/services/motion_estimator.dart';

void main() {
  TrackedObject tracked({
    required int id,
    required String label,
    required double top,
    required double bottom,
    required int timestampMs,
    double left = 0.40,
    double right = 0.60,
  }) {
    return TrackedObject(
      trackId: id,
      detection: DetectionResult(
        label: label,
        confidence: 0.9,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      firstSeenTimestampMs: timestampMs,
      lastSeenTimestampMs: timestampMs,
      seenFrames: 1,
      missedFrames: 0,
    );
  }

  test('distance decreases and approaching becomes true when box grows', () {
    final estimator = MotionEstimator(focalLengthPx: 700);

    final first = estimator.update(
      trackedObjects: [
        tracked(
          id: 1,
          label: 'person',
          top: 0.15,
          bottom: 0.45,
          timestampMs: 1000,
        ),
      ],
      frameHeightPx: 720,
      timestampMs: 1000,
    );

    final second = estimator.update(
      trackedObjects: [
        tracked(
          id: 1,
          label: 'person',
          top: 0.10,
          bottom: 0.55,
          timestampMs: 1200,
        ),
      ],
      frameHeightPx: 720,
      timestampMs: 1200,
    );

    expect(first.first.distanceReliable, isTrue);
    expect(second.first.distanceReliable, isTrue);
    expect(second.first.estimatedDistanceMeters, isNotNull);
    expect(first.first.estimatedDistanceMeters, isNotNull);

    expect(
      second.first.estimatedDistanceMeters!,
      lessThan(first.first.estimatedDistanceMeters!),
    );
    expect(second.first.approaching, isTrue);
    expect(second.first.closingSpeedMetersPerSecond, isNotNull);
  });

  test('computes time-to-collision when closing speed is positive', () {
    final estimator = MotionEstimator(focalLengthPx: 700);

    estimator.update(
      trackedObjects: [
        tracked(
          id: 2,
          label: 'person',
          top: 0.20,
          bottom: 0.45,
          timestampMs: 1000,
        ),
      ],
      frameHeightPx: 720,
      timestampMs: 1000,
    );

    final next = estimator.update(
      trackedObjects: [
        tracked(
          id: 2,
          label: 'person',
          top: 0.12,
          bottom: 0.58,
          timestampMs: 1300,
        ),
      ],
      frameHeightPx: 720,
      timestampMs: 1300,
    );

    expect(next.first.approaching, isTrue);
    expect(next.first.timeToCollisionSeconds, isNotNull);
    expect(next.first.timeToCollisionSeconds!, greaterThan(0));
  });

  test('marks distance as unreliable for unsupported classes', () {
    final estimator = MotionEstimator(focalLengthPx: 700);

    final results = estimator.update(
      trackedObjects: [
        tracked(
          id: 3,
          label: 'pole',
          top: 0.25,
          bottom: 0.70,
          timestampMs: 1000,
        ),
      ],
      frameHeightPx: 720,
      timestampMs: 1000,
    );

    expect(results.first.distanceReliable, isFalse);
    expect(results.first.estimatedDistanceMeters, isNull);
    expect(results.first.timeToCollisionSeconds, isNull);
  });
}
