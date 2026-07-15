import '../models/detection_result.dart';
import '../models/frame_metadata.dart';
import 'detection_parser.dart';

const _defaultParser = DetectionParser();

List<DetectionResult> decodeYolo({
  required Object rawOutput,
  required List<String> labels,
  double confidenceThreshold = 0.35,
}) {
  return _defaultParser.parseYolo(
    rawOutput: rawOutput,
    labels: labels,
    confidenceThreshold: confidenceThreshold,
    metadata: FrameMetadata(
      frameWidth: 640,
      frameHeight: 640,
      modelInputWidth: 640,
      modelInputHeight: 640,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
}
