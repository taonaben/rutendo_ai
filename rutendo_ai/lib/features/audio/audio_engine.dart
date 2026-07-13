import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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

  Future<void> dispose();
}

class NoopAudioBackend implements AudioPlaybackBackend {
  @override
  Future<void> playCue(AudioCueCommand command) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

AudioPlaybackBackend createDefaultAudioBackend() {
  final binding = WidgetsBinding.instance;
  final isWidgetTest = binding.runtimeType.toString().contains(
    'TestWidgetsFlutterBinding',
  );

  if (kIsWeb || isWidgetTest) {
    return NoopAudioBackend();
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => SoloudAudioBackend(),
    _ => NoopAudioBackend(),
  };
}

class SoloudAudioBackend implements AudioPlaybackBackend {
  SoloudAudioBackend({
    this.masterVolume = 0.45,
    this.staticAssetKey = 'assets/audio_cues/static_tick.wav',
    this.dynamicAssetKey = 'assets/audio_cues/dynamic_tick.wav',
    this.criticalAssetKey = 'assets/audio_cues/critical_chirp.wav',
  });

  final double masterVolume;
  final String staticAssetKey;
  final String dynamicAssetKey;
  final String criticalAssetKey;

  final Map<AudioCueFamily, AudioSource> _sources =
      <AudioCueFamily, AudioSource>{};

  SoLoud? _soloud;
  bool _initialized = false;
  bool _backendUnavailable = false;
  SoundHandle? _lastHandle;

  SoLoud? _safeSoloud() {
    if (_backendUnavailable) {
      return null;
    }

    final existing = _soloud;
    if (existing != null) {
      return existing;
    }

    try {
      final instance = SoLoud.instance;
      _soloud = instance;
      return instance;
    } catch (_) {
      _backendUnavailable = true;
      return null;
    }
  }

  Future<bool> _ensureInitialized() async {
    final soloud = _safeSoloud();
    if (soloud == null) {
      return false;
    }

    if (_initialized && soloud.isInitialized) {
      return true;
    }

    try {
      await soloud.init();
      _initialized = true;
      return true;
    } catch (_) {
      _backendUnavailable = true;
      return false;
    }
  }

  Future<AudioSource?> _sourceForFamily(AudioCueFamily family) async {
    final existing = _sources[family];
    if (existing != null) {
      return existing;
    }

    final assetKey = switch (family) {
      AudioCueFamily.staticObstacle => staticAssetKey,
      AudioCueFamily.dynamicObject => dynamicAssetKey,
      AudioCueFamily.critical => criticalAssetKey,
    };

    final soloud = _safeSoloud();
    if (soloud == null) {
      return null;
    }

    try {
      final source = await soloud.loadAsset(assetKey);
      _sources[family] = source;
      return source;
    } catch (_) {
      _backendUnavailable = true;
      return null;
    }
  }

  @override
  Future<void> playCue(AudioCueCommand command) async {
    if (!await _ensureInitialized()) {
      return;
    }

    final soloud = _safeSoloud();
    if (soloud == null) {
      return;
    }

    final source = await _sourceForFamily(command.family);
    if (source == null) {
      return;
    }

    final previous = _lastHandle;
    if (previous != null && soloud.getIsValidVoiceHandle(previous)) {
      await soloud.stop(previous);
    }

    final handle = await soloud.play(
      source,
      volume: masterVolume,
      pan: command.pan,
    );
    _lastHandle = handle;
  }

  @override
  Future<void> stopAll() async {
    final soloud = _safeSoloud();
    if (!_initialized || soloud == null || !soloud.isInitialized) {
      return;
    }

    final previous = _lastHandle;
    if (previous != null && soloud.getIsValidVoiceHandle(previous)) {
      await soloud.stop(previous);
    }
    _lastHandle = null;
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    final soloud = _safeSoloud();
    if (_initialized && soloud != null && soloud.isInitialized) {
      await soloud.disposeAllSources();
      soloud.deinit();
    }
    _sources.clear();
    _soloud = null;
    _initialized = false;
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
    unawaited(backend.dispose());
  }
}
