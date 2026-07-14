import '../models/motion_object.dart';
import '../models/tracked_object.dart';

class MotionEstimator {
  MotionEstimator({
    this.focalLengthPx = 680,
    Map<String, double>? classReferenceHeightsMeters,
  }) : classReferenceHeightsMeters =
           classReferenceHeightsMeters ?? _defaultReferenceHeights;

  final double focalLengthPx;
  final Map<String, double> classReferenceHeightsMeters;

  final Map<int, _TrackSample> _lastSampleByTrackId = <int, _TrackSample>{};

  void reset() {
    _lastSampleByTrackId.clear();
  }

  List<MotionObject> update({
    required List<TrackedObject> trackedObjects,
    required int frameHeightPx,
    required int timestampMs,
  }) {
    final currentTrackIds = trackedObjects.map((item) => item.trackId).toSet();
    _lastSampleByTrackId.removeWhere(
      (trackId, _) => !currentTrackIds.contains(trackId),
    );

    final results = <MotionObject>[];
    for (final tracked in trackedObjects) {
      final prev = _lastSampleByTrackId[tracked.trackId];
      final dtMs = prev == null ? 0 : (timestampMs - prev.timestampMs);
      final dtSec = dtMs > 0 ? dtMs / 1000.0 : 0.0;

      final centerX = tracked.detection.centerX;
      final centerY = tracked.detection.centerY;
      final area = tracked.detection.area;

      final velocityX =
          (prev != null && dtSec > 0) ? (centerX - prev.centerX) / dtSec : 0.0;
      final velocityY =
          (prev != null && dtSec > 0) ? (centerY - prev.centerY) / dtSec : 0.0;
      final areaGrowth =
          (prev != null && dtSec > 0) ? (area - prev.area) / dtSec : 0.0;

      final distanceResult = _estimateDistance(
        trackedObject: tracked,
        frameHeightPx: frameHeightPx,
      );

      double? closingSpeed;
      double? ttc;
      var approaching = false;

      if (prev != null &&
          dtSec > 0 &&
          distanceResult.distanceMeters != null &&
          prev.distanceMeters != null) {
        closingSpeed =
            (prev.distanceMeters! - distanceResult.distanceMeters!) / dtSec;
        approaching = closingSpeed > 0;

        if (approaching &&
            closingSpeed > 0 &&
            distanceResult.distanceMeters! > 0) {
          ttc = distanceResult.distanceMeters! / closingSpeed;
        }
      }

      _lastSampleByTrackId[tracked.trackId] = _TrackSample(
        timestampMs: timestampMs,
        centerX: centerX,
        centerY: centerY,
        area: area,
        distanceMeters: distanceResult.distanceMeters,
      );

      results.add(
        MotionObject(
          trackedObject: tracked,
          dtMs: dtMs,
          velocityXPerSecond: velocityX,
          velocityYPerSecond: velocityY,
          areaGrowthPerSecond: areaGrowth,
          estimatedDistanceMeters: distanceResult.distanceMeters,
          distanceReliable: distanceResult.reliable,
          approaching: approaching,
          closingSpeedMetersPerSecond: closingSpeed,
          timeToCollisionSeconds: ttc,
        ),
      );
    }

    return results;
  }

  _DistanceResult _estimateDistance({
    required TrackedObject trackedObject,
    required int frameHeightPx,
  }) {
    final classKey = trackedObject.detection.label.toLowerCase();
    final referenceHeight = classReferenceHeightsMeters[classKey];
    if (referenceHeight == null) {
      return const _DistanceResult(distanceMeters: null, reliable: false);
    }

    final boxHeightPx = trackedObject.detection.height * frameHeightPx;
    if (boxHeightPx <= 0) {
      return const _DistanceResult(distanceMeters: null, reliable: false);
    }

    final distance = (referenceHeight * focalLengthPx) / boxHeightPx;
    if (distance.isNaN || distance.isInfinite || distance <= 0) {
      return const _DistanceResult(distanceMeters: null, reliable: false);
    }

    return _DistanceResult(distanceMeters: distance, reliable: true);
  }
}

class _TrackSample {
  const _TrackSample({
    required this.timestampMs,
    required this.centerX,
    required this.centerY,
    required this.area,
    required this.distanceMeters,
  });

  final int timestampMs;
  final double centerX;
  final double centerY;
  final double area;
  final double? distanceMeters;
}

class _DistanceResult {
  const _DistanceResult({required this.distanceMeters, required this.reliable});

  final double? distanceMeters;
  final bool reliable;
}

const Map<String, double> _defaultReferenceHeights = {
  'person': 1.6,
  'car': 1.5,
  'bus': 3.0,
  'truck': 3.0,
  'motorbike': 1.2,
  'motorcycle': 1.2,
  'bicycle': 1.1,
};
