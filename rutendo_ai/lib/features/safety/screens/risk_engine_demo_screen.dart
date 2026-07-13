import 'package:flutter/material.dart';

import '../services/onnx_inference_service.dart';
import '../widgets/camera_preview_panel.dart';

class RiskEngineDemoScreen extends StatefulWidget {
  const RiskEngineDemoScreen({super.key});

  @override
  State<RiskEngineDemoScreen> createState() => _RiskEngineDemoScreenState();
}

class _RiskEngineDemoScreenState extends State<RiskEngineDemoScreen> {
  final _onnxService = OnnxInferenceService();

  String _modelStatus = 'Not loaded';
  bool _isLoadingModel = false;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Risk Engine Demo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const CameraPreviewPanel(),
            const SizedBox(height: 24),
            _ModelPanel(
              service: _onnxService,
              status: _modelStatus,
              isLoading: _isLoadingModel,
              onLoad: _loadModel,
            ),
            const SizedBox(height: 24),
            const _LiveDetectionPanel(),
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

class _LiveDetectionPanel extends StatelessWidget {
  const _LiveDetectionPanel();

  @override
  Widget build(BuildContext context) {
    return const _InfoGroup(
      title: 'Live Detection',
      rows: [
        _InfoRow(label: 'Status', value: 'Not connected yet'),
        _InfoRow(
          label: 'Next step',
          value: 'Send camera frames to ONNX and parse output0',
        ),
        _InfoRow(label: 'Risk engine', value: 'Ready for real detections'),
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
