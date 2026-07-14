import 'package:flutter_test/flutter_test.dart';
import 'package:rutendo_ai/features/safety/models/detection_result.dart';
import 'package:rutendo_ai/features/safety/services/tracker.dart';

void main() {
  DetectionResult detection({
    required String label,
    required double left,
    required double top,
    required double right,
    required double bottom,
    double confidence = 0.9,
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

  test('keeps same track id for smooth motion across frames', () {
    final tracker = SimpleTracker(iouThreshold: 0.2, maxMissedFrames: 3);

    final frame1 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.20,
          top: 0.20,
          right: 0.35,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1000,
    );
    final frame2 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.22,
          top: 0.20,
          right: 0.37,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1100,
    );
    final frame3 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.24,
          top: 0.20,
          right: 0.39,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1200,
    );

    expect(frame1, hasLength(1));
    expect(frame2, hasLength(1));
    expect(frame3, hasLength(1));

    final id = frame1.first.trackId;
    expect(frame2.first.trackId, id);
    expect(frame3.first.trackId, id);
  });

  test('retains track through a brief 2-frame occlusion', () {
    final tracker = SimpleTracker(iouThreshold: 0.2, maxMissedFrames: 3);

    final firstSeen = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.30,
          top: 0.20,
          right: 0.46,
          bottom: 0.62,
        ),
      ],
      timestampMs: 1000,
    );
    tracker.update(detections: const [], timestampMs: 1100);
    tracker.update(detections: const [], timestampMs: 1200);
    final reappeared = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.32,
          top: 0.20,
          right: 0.48,
          bottom: 0.62,
        ),
      ],
      timestampMs: 1300,
    );

    expect(firstSeen, hasLength(1));
    expect(reappeared, hasLength(1));
    expect(reappeared.first.trackId, firstSeen.first.trackId);
  });

  test('tracks two objects independently while paths cross', () {
    final tracker = SimpleTracker(iouThreshold: 0.05, maxMissedFrames: 2);

    final frame1 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.10,
          top: 0.20,
          right: 0.24,
          bottom: 0.58,
        ),
        detection(
          label: 'person',
          left: 0.68,
          top: 0.22,
          right: 0.82,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1000,
    );

    final frame2 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.18,
          top: 0.20,
          right: 0.32,
          bottom: 0.58,
        ),
        detection(
          label: 'person',
          left: 0.60,
          top: 0.22,
          right: 0.74,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1100,
    );

    final frame3 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.26,
          top: 0.20,
          right: 0.40,
          bottom: 0.58,
        ),
        detection(
          label: 'person',
          left: 0.52,
          top: 0.22,
          right: 0.66,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1200,
    );

    final frame4 = tracker.update(
      detections: [
        detection(
          label: 'person',
          left: 0.42,
          top: 0.20,
          right: 0.56,
          bottom: 0.58,
        ),
        detection(
          label: 'person',
          left: 0.36,
          top: 0.22,
          right: 0.50,
          bottom: 0.60,
        ),
      ],
      timestampMs: 1300,
    );

    expect(frame1, hasLength(2));
    expect(frame2, hasLength(2));
    expect(frame3, hasLength(2));

    final startIds = frame1.map((item) => item.trackId).toSet();
    final endIds = frame4.map((item) => item.trackId).toSet();

    expect(startIds.length, 2);
    expect(frame4, hasLength(2));
    expect(endIds.length, 2);
    expect(endIds, equals(startIds));
  });
}
