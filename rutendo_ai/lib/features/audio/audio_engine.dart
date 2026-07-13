import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../safety/models/cue_decision.dart';
import '../safety/models/hazard.dart';

enum AudioCueFamily { staticObstacle, dynamicObject, critical }

class AudioCueCommand {
  const AudioCueCommand({
    required this.trackId,
    required this.pan,
    required this.intervalMs,
    required this.family,
  });

  final int trackId;
  final double pan;
  final int intervalMs;
  final AudioCueFamily family;

  AudioCueCommand copyWith({
    int? trackId,
    double? pan,
    int? intervalMs,
    AudioCueFamily? family,
  }) {
    return AudioCueCommand(
      trackId: trackId ?? this.trackId,
      pan: pan ?? this.pan,
      intervalMs: intervalMs ?? this.intervalMs,
      family: family ?? this.family,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioCueCommand &&
        other.trackId == trackId &&
        other.pan == pan &&
        other.intervalMs == intervalMs &&
        other.family == family;
  }

  @override
  int get hashCode => Object.hash(trackId, pan, intervalMs, family);
}

abstract class AudioPlaybackBackend {
  Future<void> playCue(AudioCueCommand command);

  Future<void> stopAll();
}

class ConsoleAudioBackend implements AudioPlaybackBackend {
  @override
  Future<void> playCue(AudioCueCommand command) async {
    debugPrint(
      '[AudioCue] track=${command.trackId} family=${command.family.name} '
      'pan=${command.pan.toStringAsFixed(2)} intervalMs=${command.intervalMs}',
    );
  }

  @override
  Future<void> stopAll() async {
    debugPrint('[AudioCue] stop');
  }
}

class AudioCueMapper {
  const AudioCueMapper();

  static const Set<String> _dynamicLabels = {
    'person',
    'bicycle',
    'car',
    'motorbike',
    'motorcycle',
    'bus',
    'truck',
    'train',
  };

  double angleToPan(double angleDegrees, double fovDegrees) {
    final normalized = (angleDegrees / (fovDegrees / 2)).clamp(-1.0, 1.0);
    return normalized;
  }

  int urgencyIntervalMs(Hazard hazard) {
    final ttc = hazard.timeToCollisionSeconds;
    if (ttc != null && ttc > 0) {
      return _logScaledInterval(value: ttc, minValue: 0.5, maxValue: 6.0);
    }

    final distance = hazard.estimatedDistanceMeters;
    if (distance != null && distance > 0) {
      return _logScaledInterval(value: distance, minValue: 0.8, maxValue: 8.0);
    }

    return switch (hazard.severity) {
      HazardSeverity.critical => 170,
      HazardSeverity.high => 260,
      HazardSeverity.medium => 500,
      HazardSeverity.low => 900,
      HazardSeverity.ignore => 0,
    };
  }

  AudioCueFamily cueFamily(Hazard hazard) {
    if (hazard.ttcOverrideApplied ||
        hazard.severity == HazardSeverity.critical) {
      return AudioCueFamily.critical;
    }

    if (_dynamicLabels.contains(hazard.detection.label.toLowerCase())) {
      return AudioCueFamily.dynamicObject;
    }

    return AudioCueFamily.staticObstacle;
  }

  AudioCueCommand? fromAssessment(
    RiskAssessment assessment, {
    double fovDegrees = 66,
  }) {
    final hazard = assessment.primaryHazard;
    if (hazard == null) return null;

    final centerNormalized = (hazard.detection.centerX * 2.0) - 1.0;
    final angle = centerNormalized * (fovDegrees / 2.0);
    final pan = angleToPan(angle, fovDegrees);
    final interval = urgencyIntervalMs(hazard);
    if (interval <= 0) return null;

    return AudioCueCommand(
      trackId: hazard.trackId ?? -1,
      pan: pan,
      intervalMs: interval,
      family: cueFamily(hazard),
    );
  }

  int _logScaledInterval({
    required double value,
    required double minValue,
    required double maxValue,
  }) {
    final clamped = value.clamp(minValue, maxValue);
    final minLog = math.log(minValue);
    final maxLog = math.log(maxValue);
    final curLog = math.log(clamped);
    final normalized = (curLog - minLog) / (maxLog - minLog);

    const minInterval = 170.0;
    const maxInterval = 1000.0;
    final interval = minInterval + normalized * (maxInterval - minInterval);
    return interval.round();
  }
}

class AudioEngine {
  AudioEngine({
    required this.backend,
    this.mapper = const AudioCueMapper(),
    this.minimumRetriggerInterval = const Duration(milliseconds: 350),
  });

  final AudioPlaybackBackend backend;
  final AudioCueMapper mapper;
  final Duration minimumRetriggerInterval;

  final Map<int, DateTime> _lastPlayedByTrackId = <int, DateTime>{};

  Timer? _timer;
  AudioCueCommand? _activeCommand;

  void updateFromAssessment(
    RiskAssessment assessment, {
    double fovDegrees = 66,
  }) {
    final nextCommand = mapper.fromAssessment(
      assessment,
      fovDegrees: fovDegrees,
    );
    if (nextCommand == null) {
      _stop();
      return;
    }

    final previous = _activeCommand;
    _activeCommand = nextCommand;
    if (previous == nextCommand && _timer?.isActive == true) {
      return;
    }

    _timer?.cancel();
    _emitIfAllowed(nextCommand);
    _timer = Timer.periodic(
      Duration(milliseconds: nextCommand.intervalMs),
      (_) => _emitIfAllowed(nextCommand),
    );
  }

  void _emitIfAllowed(AudioCueCommand command) {
    final now = DateTime.now();
    final lastPlayed = _lastPlayedByTrackId[command.trackId];
    if (lastPlayed != null &&
        now.difference(lastPlayed) < minimumRetriggerInterval) {
      return;
    }

    _lastPlayedByTrackId[command.trackId] = now;
    unawaited(backend.playCue(command));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _activeCommand = null;
    unawaited(backend.stopAll());
  }

  void dispose() {
    _stop();
    _lastPlayedByTrackId.clear();
  }
}
