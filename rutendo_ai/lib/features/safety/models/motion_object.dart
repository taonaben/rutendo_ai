import 'tracked_object.dart';

class MotionObject {
  const MotionObject({
    required this.trackedObject,
    required this.dtMs,
    required this.velocityXPerSecond,
    required this.velocityYPerSecond,
    required this.areaGrowthPerSecond,
    required this.estimatedDistanceMeters,
    required this.distanceReliable,
    required this.approaching,
    required this.closingSpeedMetersPerSecond,
    required this.timeToCollisionSeconds,
  });

  final TrackedObject trackedObject;
  final int dtMs;
  final double velocityXPerSecond;
  final double velocityYPerSecond;
  final double areaGrowthPerSecond;
  final double? estimatedDistanceMeters;
  final bool distanceReliable;
  final bool approaching;
  final double? closingSpeedMetersPerSecond;
  final double? timeToCollisionSeconds;
}
