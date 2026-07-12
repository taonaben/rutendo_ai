import '../models/detection_result.dart';

List<DetectionResult> decodeYolo({
  required Object rawOutput,
  required List<String> labels,
  double confidenceThreshold = 0.35,
}) {
  final data = rawOutput;
  if (data is! List || data.isEmpty) return [];
  final batch0 = data[0];
  if (batch0 is! List || batch0.isEmpty) return [];
  final batchList = batch0 as List;
  final numDetections = batchList.length;
  if (numDetections < 1) return [];

  final results = <DetectionResult>[];

  for (var i = 0; i < numDetections; i++) {
    final det = batchList[i];
    if (det is! List || det.length < 6) continue;

    final x1 = _toDouble(det[0]);
    final y1 = _toDouble(det[1]);
    final x2 = _toDouble(det[2]);
    final y2 = _toDouble(det[3]);
    final conf = _toDouble(det[4]);
    final clsId = _toDouble(det[5]).round();

    if (conf < confidenceThreshold) continue;
    if (x1 >= x2 || y1 >= y2) continue;

    final labelIdx = clsId >= 0 && clsId < labels.length ? clsId : 0;

    results.add(DetectionResult(
      label: labels[labelIdx],
      confidence: double.parse(conf.toStringAsFixed(2)),
      left: (x1 / 640.0).clamp(0, 1).toDouble(),
      top: (y1 / 640.0).clamp(0, 1).toDouble(),
      right: (x2 / 640.0).clamp(0, 1).toDouble(),
      bottom: (y2 / 640.0).clamp(0, 1).toDouble(),
    ));
  }

  return results;
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return 0.0;
}
