import 'dart:typed_data';

import '../models/detection_result.dart';

class RawYoloDecoder {
  const RawYoloDecoder();

  List<DetectionResult> decode({
    required Object rawOutput,
    required List<String> labels,
    double confidenceThreshold = 0.35,
    double nmsIouThreshold = 0.5,
  }) {
    final data = rawOutput;
    if (data is! List || data.isEmpty) return const [];

    final batch0 = data[0];
    if (batch0 is! List || batch0.length < 15) return const [];

    // batch0 is (15, 8400) — read as column-major:
    // rows 0-3 are bbox in cxcywh pixel space (0-640)
    // rows 4-14 are class scores (already sigmoid'd by the ONNX graph)
    final numAnchors = batch0[0] is List ? (batch0[0] as List).length : 0;
    if (numAnchors == 0) return const [];
    if (numAnchors != 8400) return const [];

    final nc = labels.length;
    final candidates = <_Candidate>[];

    for (var a = 0; a < numAnchors; a++) {
      // Output is cxcywh in 0-640 pixel space — convert to xyxy
      final cx = _toDouble(batch0[0][a]);
      final cy = _toDouble(batch0[1][a]);
      final w = _toDouble(batch0[2][a]);
      final h = _toDouble(batch0[3][a]);

      if (w <= 0 || h <= 0) continue;
      var x1 = cx - w / 2;
      var y1 = cy - h / 2;
      var x2 = cx + w / 2;
      var y2 = cy + h / 2;
      if (x1 >= x2 || y1 >= y2) continue;
      // Clamp to valid pixel range
      if (x1 < 0) x1 = 0;
      if (y1 < 0) y1 = 0;
      if (x2 > 640) x2 = 640;
      if (y2 > 640) y2 = 640;

      // Find best class — scores are already sigmoid'd (0-1)
      double maxScore = 0;
      int bestCls = 0;
      for (var c = 0; c < nc; c++) {
        final score = _toDouble(batch0[4 + c][a]);
        if (score > maxScore) {
          maxScore = score;
          bestCls = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;

      candidates.add(_Candidate(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        score: maxScore,
        cls: bestCls,
      ));
    }

    // Sort by confidence descending
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // NMS
    final kept = <_Candidate>[];
    for (final c in candidates) {
      bool suppressed = false;
      for (final k in kept) {
        if (k.cls != c.cls) continue;
        final iou = _computeIou(k, c);
        if (iou > nmsIouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) {
        kept.add(c);
      }
    }

    return kept.map((c) {
      return DetectionResult(
        label: labels[c.cls],
        confidence: double.parse(c.score.toStringAsFixed(2)),
        left: c.x1 / 640.0,
        top: c.y1 / 640.0,
        right: c.x2 / 640.0,
        bottom: c.y2 / 640.0,
      );
    }).toList();
  }

  /// Decode TFLite output: flat Float32List[15 * 8400] in row-major format.
  /// Each anchor: [cx, cy, w, h, s0..s10] — bbox in 0-1 normalized space,
  /// class scores already sigmoid'd (0-1 range).
  List<DetectionResult> decodeTflite({
    required Float32List rawOutput,
    required List<String> labels,
    double confidenceThreshold = 0.35,
    double nmsIouThreshold = 0.5,
  }) {
    const int numAnchors = 8400;
    const int numChannels = 15;
    if (rawOutput.length < numAnchors * numChannels) return const [];

    final nc = labels.length;
    final candidates = <_Candidate>[];

    for (var a = 0; a < numAnchors; a++) {
      final base = a * numChannels;
      final cx = rawOutput[base];
      final cy = rawOutput[base + 1];
      final w = rawOutput[base + 2];
      final h = rawOutput[base + 3];

      if (w <= 0 || h <= 0) continue;
      var x1 = cx - w / 2;
      var y1 = cy - h / 2;
      var x2 = cx + w / 2;
      var y2 = cy + h / 2;
      if (x1 >= x2 || y1 >= y2) continue;
      if (x1 < 0) x1 = 0;
      if (y1 < 0) y1 = 0;
      if (x2 > 1) x2 = 1;
      if (y2 > 1) y2 = 1;

      double maxScore = 0;
      int bestCls = 0;
      for (var c = 0; c < nc; c++) {
        final score = rawOutput[base + 4 + c];
        if (score > maxScore) {
          maxScore = score;
          bestCls = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;

      candidates.add(_Candidate(
        x1: x1, y1: y1, x2: x2, y2: y2,
        score: maxScore, cls: bestCls,
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final kept = <_Candidate>[];
    for (final c in candidates) {
      bool suppressed = false;
      for (final k in kept) {
        if (k.cls != c.cls) continue;
        if (_computeIou(k, c) > nmsIouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) kept.add(c);
    }

    return kept.map((c) => DetectionResult(
      label: labels[c.cls],
      confidence: double.parse(c.score.toStringAsFixed(2)),
      left: c.x1,
      top: c.y1,
      right: c.x2,
      bottom: c.y2,
    )).toList();
  }

  /// Decode TFLite output with column-major (NCHW) layout: [c * 8400 + a].
  /// Output shape [1, 15, 8400], each anchor: [cx, cy, w, h, s0..s10] (sigmoid'd).
  List<DetectionResult> decodeTfliteColumnar({
    required Float32List rawOutput,
    required List<String> labels,
    double confidenceThreshold = 0.35,
    double nmsIouThreshold = 0.5,
  }) {
    const int numAnchors = 8400;
    const int numChannels = 15;
    if (rawOutput.length < numChannels * numAnchors) return const [];

    final nc = labels.length;
    final candidates = <_Candidate>[];

    for (var a = 0; a < numAnchors; a++) {
      final cx = rawOutput[a];
      final cy = rawOutput[numAnchors + a];
      final w = rawOutput[2 * numAnchors + a];
      final h = rawOutput[3 * numAnchors + a];

      if (w <= 0 || h <= 0) continue;
      var x1 = cx - w / 2;
      var y1 = cy - h / 2;
      var x2 = cx + w / 2;
      var y2 = cy + h / 2;
      if (x1 >= x2 || y1 >= y2) continue;
      if (x1 < 0) x1 = 0;
      if (y1 < 0) y1 = 0;
      if (x2 > 1) x2 = 1;
      if (y2 > 1) y2 = 1;

      double maxScore = 0;
      int bestCls = 0;
      for (var c = 0; c < nc; c++) {
        final score = rawOutput[(4 + c) * numAnchors + a];
        if (score > maxScore) {
          maxScore = score;
          bestCls = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;

      candidates.add(_Candidate(
        x1: x1, y1: y1, x2: x2, y2: y2,
        score: maxScore, cls: bestCls,
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final kept = <_Candidate>[];
    for (final c in candidates) {
      bool suppressed = false;
      for (final k in kept) {
        if (k.cls != c.cls) continue;
        if (_computeIou(k, c) > nmsIouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) kept.add(c);
    }

    return kept.map((c) => DetectionResult(
      label: labels[c.cls],
      confidence: double.parse(c.score.toStringAsFixed(2)),
      left: c.x1,
      top: c.y1,
      right: c.x2,
      bottom: c.y2,
    )).toList();
  }

  double _computeIou(_Candidate a, _Candidate b) {
    final ix1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final iy1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final ix2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final iy2 = a.y2 < b.y2 ? a.y2 : b.y2;
    if (ix2 <= ix1 || iy2 <= iy1) return 0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    return inter / (areaA + areaB - inter);
  }
}

class _Candidate {
  final double x1, y1, x2, y2;
  final double score;
  final int cls;
  const _Candidate({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.cls,
  });
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return 0.0;
}
