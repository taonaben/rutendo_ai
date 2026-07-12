import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxModelAssets {
  const OnnxModelAssets._();

  static const modelPath = 'assets/models/best.onnx';
  static const labelsPath = 'assets/models/labels.txt';
}

class OnnxInferenceService {
  OnnxInferenceService({
    this.modelPath = OnnxModelAssets.modelPath,
    this.labelsPath = OnnxModelAssets.labelsPath,
  });

  final String modelPath;
  final String labelsPath;

  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  List<String> _labels = const [];

  bool get isLoaded => _session != null;

  List<String> get labels => List.unmodifiable(_labels);

  List<String> get inputNames => List.unmodifiable(_session?.inputNames ?? []);

  List<String> get outputNames =>
      List.unmodifiable(_session?.outputNames ?? []);

  Future<void> load() async {
    if (isLoaded) {
      return;
    }

    OrtEnv.instance.init();

    final labelsText = await rootBundle.loadString(labelsPath);
    _labels =
        labelsText
            .split('\n')
            .map((label) => label.trim())
            .where((label) => label.isNotEmpty)
            .toList(growable: false);

    final modelBytes = await rootBundle.load(modelPath);
    _sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(),
      _sessionOptions!,
    );
  }

  Future<List<OrtValue?>> runRaw({
    required String inputName,
    required Float32List input,
    required List<int> inputShape,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('ONNX model is not loaded. Call load() first.');
    }

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      input,
      inputShape,
    );
    final runOptions = OrtRunOptions();

    try {
      final outputFuture = session.runAsync(runOptions, {
        inputName: inputTensor,
      });
      if (outputFuture == null) {
        return const [];
      }
      return await outputFuture;
    } finally {
      inputTensor.release();
      runOptions.release();
    }
  }

  void release() {
    _session?.release();
    _session = null;
    _sessionOptions?.release();
    _sessionOptions = null;
    OrtEnv.instance.release();
  }
}
