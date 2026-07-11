import 'package:flutter/material.dart';

import '../models/cue_decision.dart';
import '../models/detection_result.dart';
import '../models/hazard.dart';
import '../services/onnx_inference_service.dart';
import '../services/risk_engine.dart';
import '../widgets/camera_preview_panel.dart';

class RiskEngineDemoScreen extends StatefulWidget {
  const RiskEngineDemoScreen({super.key});

  @override
  State<RiskEngineDemoScreen> createState() => _RiskEngineDemoScreenState();
}

class _RiskEngineDemoScreenState extends State<RiskEngineDemoScreen> {
  static const _riskEngine = RiskEngine();

  final _onnxService = OnnxInferenceService();

  late _DemoScenario _selectedScenario = _scenarios.first;
  late RiskAssessment _assessment = _riskEngine.assess(
    _selectedScenario.detections,
  );
  String _modelStatus = 'Not loaded';
  bool _isLoadingModel = false;

  void _selectScenario(_DemoScenario scenario) {
    setState(() {
      _selectedScenario = scenario;
      _assessment = _riskEngine.assess(scenario.detections);
    });
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoadingModel = true;
      _modelStatus = 'Loading ONNX model...';
    });

    try {
      await _onnxService.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _modelStatus = 'Loaded';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _modelStatus = 'Failed to load: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModel = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _onnxService.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hazard = _assessment.primaryHazard;

    return Scaffold(
      appBar: AppBar(title: const Text('Risk Engine Demo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Scenario', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_selectedScenario.description),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scenario in _scenarios)
                  FilledButton.tonal(
                    onPressed: () => _selectScenario(scenario),
                    child: Text(scenario.name),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const CameraPreviewPanel(),
            const SizedBox(height: 24),
            _ModelPanel(
              service: _onnxService,
              status: _modelStatus,
              isLoading: _isLoadingModel,
              onLoad: _loadModel,
            ),
            const SizedBox(height: 24),
            _ResultPanel(assessment: _assessment, hazard: hazard),
          ],
        ),
      ),
    );
  }
}

class _ModelPanel extends StatelessWidget {
  const _ModelPanel({
    required this.service,
    required this.status,
    required this.isLoading,
    required this.onLoad,
  });

  final OnnxInferenceService service;
  final String status;
  final bool isLoading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return _InfoGroup(
      title: 'ONNX Model',
      action: FilledButton(
        onPressed: isLoading ? null : onLoad,
        child: Text(isLoading ? 'Loading...' : 'Load model'),
      ),
      rows: [
        _InfoRow(label: 'Status', value: status),
        _InfoRow(label: 'Model', value: OnnxModelAssets.modelPath),
        _InfoRow(label: 'Labels', value: _formatList(service.labels)),
        _InfoRow(label: 'Inputs', value: _formatList(service.inputNames)),
        _InfoRow(label: 'Outputs', value: _formatList(service.outputNames)),
      ],
    );
  }

  String _formatList(List<String> values) {
    if (values.isEmpty) {
      return 'Not available yet';
    }
    return values.join(', ');
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.assessment, required this.hazard});

  final RiskAssessment assessment;
  final Hazard? hazard;

  @override
  Widget build(BuildContext context) {
    final selectedHazard = hazard;

    if (selectedHazard == null) {
      return const _InfoGroup(
        title: 'Decision',
        rows: [
          _InfoRow(label: 'Status', value: 'No alert'),
          _InfoRow(label: 'Reason', value: 'No important hazard selected'),
          _InfoRow(label: 'Audio', value: 'none'),
          _InfoRow(label: 'Haptic', value: 'none'),
        ],
      );
    }

    return _InfoGroup(
      title: 'Decision',
      rows: [
        _InfoRow(label: 'Object', value: selectedHazard.detection.label),
        _InfoRow(label: 'Zone', value: selectedHazard.zone.name),
        _InfoRow(label: 'Distance', value: selectedHazard.distance.name),
        _InfoRow(label: 'Severity', value: selectedHazard.severity.name),
        _InfoRow(label: 'Reason', value: selectedHazard.reason),
        _InfoRow(
          label: 'Audio',
          value:
              '${assessment.audioCue.pattern.name} '
              '(${assessment.audioCue.intervalMs}ms)',
        ),
        _InfoRow(
          label: 'Haptic',
          value:
              '${assessment.hapticCue.pattern.name} '
              '(${assessment.hapticCue.durationMs}ms)',
        ),
        _InfoRow(label: 'Hazards shown', value: '${assessment.hazards.length}'),
      ],
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.rows, this.action});

  final String title;
  final List<_InfoRow> rows;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              row,
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(value),
      ],
    );
  }
}

class _DemoScenario {
  const _DemoScenario({
    required this.name,
    required this.description,
    required this.detections,
  });

  final String name;
  final String description;
  final List<DetectionResult> detections;
}

const _scenarios = [
  _DemoScenario(
    name: 'Near center',
    description: 'A chair is close and directly in the walking path.',
    detections: [
      DetectionResult(
        label: 'chair',
        confidence: 0.86,
        left: 0.40,
        top: 0.20,
        right: 0.60,
        bottom: 0.96,
      ),
    ],
  ),
  _DemoScenario(
    name: 'Car right',
    description: 'A car is medium distance on the right side.',
    detections: [
      DetectionResult(
        label: 'car',
        confidence: 0.81,
        left: 0.68,
        top: 0.30,
        right: 0.94,
        bottom: 0.75,
      ),
    ],
  ),
  _DemoScenario(
    name: 'Far bench',
    description: 'A bench is far away and should not trigger an alert.',
    detections: [
      DetectionResult(
        label: 'bench',
        confidence: 0.92,
        left: 0.37,
        top: 0.10,
        right: 0.56,
        bottom: 0.35,
      ),
    ],
  ),
  _DemoScenario(
    name: 'Multiple',
    description: 'Several detections arrive, but only the top hazards matter.',
    detections: [
      DetectionResult(
        label: 'person',
        confidence: 0.88,
        left: 0.40,
        top: 0.20,
        right: 0.60,
        bottom: 0.95,
      ),
      DetectionResult(
        label: 'car',
        confidence: 0.74,
        left: 0.68,
        top: 0.28,
        right: 0.96,
        bottom: 0.77,
      ),
      DetectionResult(
        label: 'chair',
        confidence: 0.90,
        left: 0.05,
        top: 0.20,
        right: 0.30,
        bottom: 0.82,
      ),
    ],
  ),
];
