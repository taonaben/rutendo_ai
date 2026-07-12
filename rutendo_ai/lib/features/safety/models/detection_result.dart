import 'dart:math' as math;

enum DetectionZone { left, center, right }

enum EstimatedDistance { near, medium, far }

class DetectionResult {
  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(confidence >= 0 && confidence <= 1),
       assert(left >= 0 && left <= 1),
       assert(top >= 0 && top <= 1),
       assert(right >= 0 && right <= 1),
       assert(bottom >= 0 && bottom <= 1),
       assert(left <= right),
       assert(top <= bottom);

  final String label;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;

  double get centerY => (top + bottom) / 2;

  double get width => math.max(0, right - left);

  double get height => math.max(0, bottom - top);

  double get area => width * height;

  DetectionZone get zone {
    if (centerX < 0.33) {
      return DetectionZone.left;
    }
    if (centerX > 0.66) {
      return DetectionZone.right;
    }
    return DetectionZone.center;
  }

  EstimatedDistance get estimatedDistance {
    if (height >= 0.55 || bottom >= 0.92) {
      return EstimatedDistance.near;
    }
    if (height >= 0.30 || bottom >= 0.72) {
      return EstimatedDistance.medium;
    }
    return EstimatedDistance.far;
  }
}
