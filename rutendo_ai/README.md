# Rutendo AI

Rutendo AI is a Flutter MVP for assistive obstacle awareness. The phone camera
detects objects, the app estimates whether they are relevant to the walking
path, and the user receives directional audio and vibration feedback.

## MVP Pipeline

```text
camera frame
  -> TFLite object detection
  -> DetectionResult list
  -> Dart RiskEngine
  -> AudioCueDecision + HapticCueDecision
  -> left / center / right beeps and vibration
```

The model should only answer: "what object did we see, with what confidence,
and where is its bounding box?"

The risk engine answers the product question: "does this matter to the user
right now?"

## Group System Design

The work can be split into clear ownership areas:

| Area | Main files | Responsibility |
| --- | --- | --- |
| Camera | `camera_service.dart` | Reads camera frames and skips frames when inference is busy. |
| Inference | `inference_service.dart` | Resizes frames, runs the TFLite model, and returns raw detections. |
| Risk engine | `lib/features/safety/services/risk_engine.dart` | Scores detections, chooses the top hazards, and decides feedback urgency. |
| Audio | `audio_cue_service.dart` | Plays left, center, and right beep patterns. |
| Haptics | `haptic_service.dart` | Triggers vibration patterns for near or critical hazards. |
| UI | `main.dart` and future screens | Shows app state, permissions, and debug information during testing. |

For the MVP, the risk engine is intentionally written in Dart because it is
fast product logic, not model logic. It should stay readable and easy to tune
after real walking tests.

## Risk Engine Rules

The current Dart implementation uses simple rules:

- Ignore detections below the confidence threshold.
- Split the image into `left`, `center`, and `right` zones using the bounding
  box center.
- Estimate rough distance from bounding box height and how close the box is to
  the bottom of the image.
- Treat near center objects as high priority.
- Treat medium or near vehicles as high priority.
- Ignore far non-vehicle objects to avoid audio overload.
- Return only the top 1-2 hazards so the user is not overwhelmed.

## Risk Engine Contract

Input from inference:

```dart
DetectionResult(
  label: 'person',
  confidence: 0.82,
  left: 0.12,
  top: 0.20,
  right: 0.35,
  bottom: 0.80,
)
```

Output to feedback services:

```dart
RiskAssessment(
  hazards: [...],
  audioCue: AudioCueDecision(...),
  hapticCue: HapticCueDecision(...),
)
```

The audio service should use `audioCue.zone` to pan or choose the left, center,
or right sound. It should use `audioCue.intervalMs` to control beep speed.

The haptic service should use `hapticCue.pattern` and `hapticCue.durationMs` for
vibration strength and length.

## Implemented Files

- `lib/features/safety/models/detection_result.dart`
- `lib/features/safety/models/hazard.dart`
- `lib/features/safety/models/cue_decision.dart`
- `lib/features/safety/services/risk_engine.dart`
- `test/risk_engine_test.dart`

## Testing

Run:

```bash
flutter test
```

The risk engine tests cover:

- near center obstacle priority
- far object filtering
- medium-distance vehicle alerts
- top two hazard selection
