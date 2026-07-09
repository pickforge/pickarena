import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EvaluatorWeightsSection extends StatefulWidget {
  const EvaluatorWeightsSection({super.key, this.repo});
  final SettingsStore? repo;

  @override
  State<EvaluatorWeightsSection> createState() =>
      _EvaluatorWeightsSectionState();
}

class _EvaluatorWeightsSectionState extends State<EvaluatorWeightsSection> {
  late final SettingsStore _repo;
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? context.read<SettingsStore>();
    for (final id in defaultEvaluatorWeights.keys) {
      _controllers[id] = TextEditingController()
        ..addListener(() => setState(() {}));
    }
    _load();
  }

  Future<void> _load() async {
    final effective = await _repo.getEvaluatorWeights();
    if (!mounted) return;
    setState(() {
      for (final id in defaultEvaluatorWeights.keys) {
        final v = effective[id] ?? defaultEvaluatorWeights[id]!;
        _controllers[id]!.text = _isDefault(id, v) ? '' : v.toString();
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isDefault(String id, double v) {
    final def = defaultEvaluatorWeights[id]!;
    return (v - def).abs() < 1e-9;
  }

  /// Returns the parsed value for [id], or null if the row is invalid.
  /// Empty input returns the default.
  double? _parsed(String id) {
    final text = _controllers[id]!.text.trim();
    if (text.isEmpty) return defaultEvaluatorWeights[id];
    final v = double.tryParse(text);
    if (v == null || v < 0) return null;
    return v;
  }

  bool get _allValid =>
      defaultEvaluatorWeights.keys.every((id) => _parsed(id) != null);

  Map<String, double> _effectiveWeights() {
    final out = <String, double>{};
    for (final id in defaultEvaluatorWeights.keys) {
      out[id] = _parsed(id) ?? defaultEvaluatorWeights[id]!;
    }
    return out;
  }

  Map<String, double> _overrides() {
    final out = <String, double>{};
    for (final id in defaultEvaluatorWeights.keys) {
      final v = _parsed(id);
      if (v == null) continue;
      if (!_isDefault(id, v)) out[id] = v;
    }
    return out;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    await _repo.setEvaluatorWeights(_overrides());
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Evaluator weights saved')),
    );
  }

  void _resetRow(String id) {
    setState(() => _controllers[id]!.text = '');
  }

  void _resetAll() {
    setState(() {
      for (final c in _controllers.values) {
        c.text = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evaluator Weights',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final id in defaultEvaluatorWeights.keys) _row(context, id),
            const Divider(height: 32),
            _DistributionPreview(weights: _effectiveWeights()),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _allValid ? _save : null,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _resetAll,
                  child: const Text('Reset all to defaults'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String id) {
    final parsed = _parsed(id);
    final isDefault = parsed != null && _isDefault(id, parsed);
    final isInvalid = parsed == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(id, style: const TextStyle(fontFamily: 'monospace')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: ValueKey('weight-field-$id'),
              controller: _controllers[id],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: defaultEvaluatorWeights[id]!.toString(),
                border: const OutlineInputBorder(),
                errorText: isInvalid ? 'must be ≥ 0' : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            label: Text(isDefault ? 'Default' : 'Override'),
            backgroundColor: isDefault
                ? Colors.green.shade700
                : Colors.orange.shade800,
          ),
          IconButton(
            key: ValueKey('weight-reset-$id'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to default',
            onPressed: () => _resetRow(id),
          ),
        ],
      ),
    );
  }
}

class _DistributionPreview extends StatelessWidget {
  const _DistributionPreview({required this.weights});
  final Map<String, double> weights;

  @override
  Widget build(BuildContext context) {
    final sum = weights.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) {
      return const Text(
        'Normalized distribution: (all weights are zero)',
        style: TextStyle(fontSize: 12),
      );
    }
    final colors = <Color>[
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.amber.shade400,
      Colors.green.shade400,
      Colors.teal.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
    ];
    final ids = weights.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Normalized distribution',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 16,
          child: Row(
            children: [
              for (var i = 0; i < ids.length; i++)
                Expanded(
                  flex: ((weights[ids[i]]! / sum) * 1000)
                      .round()
                      .clamp(1, 1000)
                      .toInt(),
                  child: Container(color: colors[i % colors.length]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var i = 0; i < ids.length; i++)
              Chip(
                label: Text(
                  '${ids[i]} ${((weights[ids[i]]! / sum) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: colors[i % colors.length].withValues(
                  alpha: 0.2,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}
