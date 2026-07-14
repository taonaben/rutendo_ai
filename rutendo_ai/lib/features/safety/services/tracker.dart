import '../models/detection_result.dart';
import '../models/tracked_object.dart';

class SimpleTracker {
  SimpleTracker({this.iouThreshold = 0.3, this.maxMissedFrames = 3})
    : assert(iouThreshold > 0 && iouThreshold <= 1),
      assert(maxMissedFrames >= 0);

  final double iouThreshold;
  final int maxMissedFrames;

  final Map<int, _TrackState> _tracks = <int, _TrackState>{};
  int _nextTrackId = 1;

  void reset() {
    _tracks.clear();
    _nextTrackId = 1;
  }

  List<TrackedObject> update({
    required List<DetectionResult> detections,
    required int timestampMs,
  }) {
    final unmatchedDetections = <int>{
      for (var i = 0; i < detections.length; i++) i,
    };
    final unmatchedTracks = _tracks.keys.toSet();

    final matches = <_Match>[];
    while (true) {
      _Match? bestMatch;
      for (final trackId in unmatchedTracks) {
        final track = _tracks[trackId];
        if (track == null) continue;
        for (final detIndex in unmatchedDetections) {
          final iou = _iou(track.detection, detections[detIndex]);
          if (iou < iouThreshold) continue;

          if (bestMatch == null || iou > bestMatch.iou) {
            bestMatch = _Match(
              trackId: trackId,
              detectionIndex: detIndex,
              iou: iou,
            );
          }
        }
      }

      if (bestMatch == null) break;

      matches.add(bestMatch);
      unmatchedTracks.remove(bestMatch.trackId);
      unmatchedDetections.remove(bestMatch.detectionIndex);
    }

    final updatedTrackIds = <int>{};

    for (final match in matches) {
      final existing = _tracks[match.trackId];
      if (existing == null) continue;

      _tracks[match.trackId] = existing.copyWith(
        detection: detections[match.detectionIndex],
        lastSeenTimestampMs: timestampMs,
        seenFrames: existing.seenFrames + 1,
        missedFrames: 0,
      );
      updatedTrackIds.add(match.trackId);
    }

    for (final detectionIndex in unmatchedDetections) {
      final trackId = _nextTrackId++;
      _tracks[trackId] = _TrackState(
        trackId: trackId,
        detection: detections[detectionIndex],
        firstSeenTimestampMs: timestampMs,
        lastSeenTimestampMs: timestampMs,
        seenFrames: 1,
        missedFrames: 0,
      );
      updatedTrackIds.add(trackId);
    }

    for (final trackId in unmatchedTracks) {
      final track = _tracks[trackId];
      if (track == null) continue;

      final nextMissed = track.missedFrames + 1;
      if (nextMissed > maxMissedFrames) {
        _tracks.remove(trackId);
        continue;
      }

      _tracks[trackId] = track.copyWith(missedFrames: nextMissed);
    }

    final updatedTracks = updatedTrackIds
      .map((trackId) => _tracks[trackId])
      .whereType<_TrackState>()
      .toList(growable: false)..sort((a, b) => a.trackId.compareTo(b.trackId));

    return updatedTracks
        .map(
          (track) => TrackedObject(
            trackId: track.trackId,
            detection: track.detection,
            firstSeenTimestampMs: track.firstSeenTimestampMs,
            lastSeenTimestampMs: track.lastSeenTimestampMs,
            seenFrames: track.seenFrames,
            missedFrames: track.missedFrames,
          ),
        )
        .toList(growable: false);
  }
}

double _iou(DetectionResult a, DetectionResult b) {
  final left = a.left > b.left ? a.left : b.left;
  final top = a.top > b.top ? a.top : b.top;
  final right = a.right < b.right ? a.right : b.right;
  final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;

  if (left >= right || top >= bottom) return 0.0;

  final intersection = (right - left) * (bottom - top);
  final union = a.area + b.area - intersection;
  if (union <= 0) return 0.0;

  return intersection / union;
}

class _TrackState {
  const _TrackState({
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

  _TrackState copyWith({
    DetectionResult? detection,
    int? firstSeenTimestampMs,
    int? lastSeenTimestampMs,
    int? seenFrames,
    int? missedFrames,
  }) {
    return _TrackState(
      trackId: trackId,
      detection: detection ?? this.detection,
      firstSeenTimestampMs: firstSeenTimestampMs ?? this.firstSeenTimestampMs,
      lastSeenTimestampMs: lastSeenTimestampMs ?? this.lastSeenTimestampMs,
      seenFrames: seenFrames ?? this.seenFrames,
      missedFrames: missedFrames ?? this.missedFrames,
    );
  }
}

class _Match {
  const _Match({
    required this.trackId,
    required this.detectionIndex,
    required this.iou,
  });

  final int trackId;
  final int detectionIndex;
  final double iou;
}
