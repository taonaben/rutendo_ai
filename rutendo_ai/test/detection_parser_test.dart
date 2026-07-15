import 'package:flutter_test/flutter_test.dart';
import 'package:rutendo_ai/features/safety/models/frame_metadata.dart';
import 'package:rutendo_ai/features/safety/services/detection_parser.dart';

void main() {
  const parser = DetectionParser();
  const labels = ['person', 'car'];

  const metadata = FrameMetadata(
    frameWidth: 1280,
    frameHeight: 720,
    modelInputWidth: 640,
    modelInputHeight: 640,
    timestampMs: 123,
  );

  test('parses valid detections and applies confidence threshold', () {
    final raw = [
      [
        [64.0, 64.0, 256.0, 320.0, 0.90, 0.0],
        [128.0, 128.0, 300.0, 400.0, 0.20, 1.0],
      ],
    ];

    final results = parser.parseYolo(
      rawOutput: raw,
      labels: labels,
      metadata: metadata,
      confidenceThreshold: 0.35,
    );

    expect(results, hasLength(1));
    expect(results.first.label, 'person');
    expect(results.first.confidence, 0.9);
  });

  test(
    'scales model coordinates into frame coordinates before normalization',
    () {
      final raw = [
        [
          [64.0, 64.0, 256.0, 320.0, 0.90, 1.0],
        ],
      ];

      final results = parser.parseYolo(
        rawOutput: raw,
        labels: labels,
        metadata: metadata,
      );

      expect(results, hasLength(1));
      final detection = results.first;

      expect(detection.left, closeTo(0.10, 0.0001));
      expect(detection.top, closeTo(0.10, 0.0001));
      expect(detection.right, closeTo(0.40, 0.0001));
      expect(detection.bottom, closeTo(0.50, 0.0001));
      expect(detection.label, 'car');
    },
  );

  test('returns empty list for malformed tensor outputs', () {
    final resultsA = parser.parseYolo(
      rawOutput: const <Object>[],
      labels: labels,
      metadata: metadata,
    );
    final resultsB = parser.parseYolo(
      rawOutput: const [
        [
          [1.0, 2.0, 3.0],
        ],
      ],
      labels: labels,
      metadata: metadata,
    );

    expect(resultsA, isEmpty);
    expect(resultsB, isEmpty);
  });
}
