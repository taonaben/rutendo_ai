import 'detection_result.dart';
import 'hazard.dart';

enum AudioCuePattern { none, slowBeep, mediumBeep, fastBeep, urgentPulse }

enum HapticCuePattern { none, lightPulse, mediumPulse, strongPulse }

class AudioCueDecision {
  const AudioCueDecision({
    required this.pattern,
    this.zone,
    required this.intervalMs,
  });

  final AudioCuePattern pattern;
  final DetectionZone? zone;
  final int intervalMs;
}

class HapticCueDecision {
  const HapticCueDecision({required this.pattern, required this.durationMs});

  final HapticCuePattern pattern;
  final int durationMs;
}

class RiskAssessment {
  const RiskAssessment({
    required this.hazards,
    required this.audioCue,
    required this.hapticCue,
  });

  final List<Hazard> hazards;
  final AudioCueDecision audioCue;
  final HapticCueDecision hapticCue;

  Hazard? get primaryHazard => hazards.isEmpty ? null : hazards.first;
}
