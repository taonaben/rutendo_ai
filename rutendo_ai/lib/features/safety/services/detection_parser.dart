import '../models/detection_result.dart';
import '../models/frame_metadata.dart';

class DetectionParser {
  const DetectionParser();

  List<DetectionResult> parseYolo({
    required Object rawOutput,
    required List<String> labels,
    required FrameMetadata metadata,
    double confidenceThreshold = 0.35,
  }) {
    final data = rawOutput;
    if (data is! List || data.isEmpty) return const [];

    final batch0 = data[0];
    if (batch0 is! List || batch0.isEmpty) return const [];

    final xScale = metadata.frameWidth / metadata.modelInputWidth;
    final yScale = metadata.frameHeight / metadata.modelInputHeight;
    final frameWidth = metadata.frameWidth.toDouble();
    final frameHeight = metadata.frameHeight.toDouble();

    final results = <DetectionResult>[];
    for (final det in batch0) {
      if (det is! List || det.length < 6) continue;

      final x1 = _toDouble(det[0]);
      final y1 = _toDouble(det[1]);
      final x2 = _toDouble(det[2]);
      final y2 = _toDouble(det[3]);
      final conf = _toDouble(det[4]);
      final clsId = _toDouble(det[5]).round();

      if (conf < confidenceThreshold) continue;
      if (x1 >= x2 || y1 >= y2) continue;

      final labelIndex = clsId >= 0 && clsId < labels.length ? clsId : 0;

      final scaledX1 = (x1 * xScale).clamp(0.0, frameWidth);
      final scaledY1 = (y1 * yScale).clamp(0.0, frameHeight);
      final scaledX2 = (x2 * xScale).clamp(0.0, frameWidth);
      final scaledY2 = (y2 * yScale).clamp(0.0, frameHeight);

      if (scaledX1 >= scaledX2 || scaledY1 >= scaledY2) continue;

      results.add(
        DetectionResult(
          label: labels[labelIndex],
          confidence: double.parse(conf.toStringAsFixed(2)),
          left: (scaledX1 / frameWidth).clamp(0, 1).toDouble(),
          top: (scaledY1 / frameHeight).clamp(0, 1).toDouble(),
          right: (scaledX2 / frameWidth).clamp(0, 1).toDouble(),
          bottom: (scaledY2 / frameHeight).clamp(0, 1).toDouble(),
        ),
      );
    }

    return results;
  }
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return 0.0;
}
