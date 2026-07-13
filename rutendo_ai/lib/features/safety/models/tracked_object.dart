import 'detection_result.dart';

class TrackedObject {
  const TrackedObject({
    required this.trackId,
    required this.detection,
    required this.firstSeenTimestampMs,
    required this.lastSeenTimestampMs,
    required this.seenFrames,
    required this.missedFrames,
  });

  final int trackId;
  final DetectionResult detection;
  final int firstSeenTimestampMs;
  final int lastSeenTimestampMs;
  final int seenFrames;
  final int missedFrames;
}
