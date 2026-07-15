import 'dart:typed_data';

import 'package:flutter/services.dart';

class OnnxModelAssets {
  const OnnxModelAssets._();

  static const tfliteModelPath = 'assets/models/yolo11n.tflite';
  static const cocoPrunedLabelsPath = 'assets/models/labels.txt';

  static const roboflowModelPath = 'assets/models/roboflow_10class.onnx';
  static const roboflowLabelsPath = 'assets/models/roboflow_10class_labels.txt';

  /// Default: TFLite model for GPU-accelerated inference
  static const modelPath = tfliteModelPath;
  static const labelsPath = cocoPrunedLabelsPath;
}

class OnnxInferenceService {
  OnnxInferenceService({
    this.modelPath = OnnxModelAssets.modelPath,
    this.labelsPath = OnnxModelAssets.labelsPath,
  });

  final String modelPath;
  final String labelsPath;

  Uint8List? _modelBytes;
  List<String> _labels = const [];

  bool get isLoaded => _modelBytes != null;

  Uint8List? get modelBytes => _modelBytes;

  List<String> get labels => List.unmodifiable(_labels);

  Future<void> load() async {
    if (isLoaded) return;

    final labelsText = await rootBundle.loadString(labelsPath);
    _labels =
        labelsText
            .split('\n')
            .map((label) => label.trim())
            .where((label) => label.isNotEmpty)
            .toList(growable: false);

    final bytes = await rootBundle.load(modelPath);
    _modelBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  }

  void release() {
    _modelBytes = null;
    _labels = const [];
  }
}
