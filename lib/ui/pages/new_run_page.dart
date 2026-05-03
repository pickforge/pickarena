import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NewRunPage extends StatefulWidget {
  const NewRunPage({super.key, this.registry, this.providers});

  final TaskRegistry? registry;
  final List<ModelProvider>? providers;

  @override
  State<NewRunPage> createState() => _NewRunPageState();
}

class _NewRunPageState extends State<NewRunPage> {
  late final TaskRegistry _registry;
  List<ModelProvider> _providers = [];
  final Map<String, bool> _checkedProvider = {};
  final Map<String, String> _models = {};
  final Set<String> _selectedTaskIds = {};
  String _label = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _registry = widget.registry ?? buildDefaultTaskRegistry();
    for (final t in _registry.all()) {
      _selectedTaskIds.add(t.id);
    }
    if (widget.providers != null) {
      _providers = widget.providers!;
      _loading = false;
    } else {
      _loadProviders();
    }
  }

  Future<void> _loadProviders() async {
    final p = await buildEnabledProviders(SettingsRepository());
    if (!mounted) return;
    setState(() {
      _providers = p;
      _loading = false;
    });
  }

  bool get _canRun {
    if (_selectedTaskIds.isEmpty) return false;
    final selectedProviders =
        _providers.where((p) => _checkedProvider[p.id] == true).toList();
    if (selectedProviders.isEmpty) return false;
    for (final pr in selectedProviders) {
      final m = _models[pr.id];
      if (m == null || m.trim().isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Run')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _LabelField(onChanged: (v) => _label = v),
                      const SizedBox(height: 16),
                      _TaskPicker(
                        registry: _registry,
                        selected: _selectedTaskIds,
                        onChanged: (id, v) => setState(() {
                          if (v) {
                            _selectedTaskIds.add(id);
                          } else {
                            _selectedTaskIds.remove(id);
                          }
                        }),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Providers',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ..._providers.map(
                        (provider) => _ProviderRow(
                          provider: provider,
                          checked: _checkedProvider[provider.id] ?? false,
                          onChecked: (v) => setState(
                              () => _checkedProvider[provider.id] = v),
                          onModelChanged: (v) =>
                              setState(() => _models[provider.id] = v),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canRun ? _startRun : null,
                      child: const Text('Run'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _startRun() async {
    final selectedProviders =
        _providers.where((p) => _checkedProvider[p.id] == true).toList();
    final modelMap = {
      for (final p in selectedProviders) p.id: _models[p.id] ?? '',
    };
    final selectedTasks = _registry
        .all()
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();

    final docs = await getApplicationSupportDirectory();
    final root = Directory(p.join(docs.path, 'workdirs'))
      ..createSync(recursive: true);
    final db = AppDatabase();
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: root),
      runDao: RunDao(db),
      now: () => DateTime.now(),
      idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
    );

    final settings = SettingsRepository();
    final judgeProviderId = await settings.getJudgeProviderId();
    final judgeModelId = await settings.getJudgeModelId();
    ModelProvider? judgeProvider;
    if (judgeProviderId != null && judgeModelId != null) {
      for (final candidate in _providers) {
        if (candidate.id == judgeProviderId) {
          judgeProvider = candidate;
          break;
        }
      }
    }
    final evaluatorConfig = EvaluatorConfig(
      judgeProvider: judgeProvider,
      judgeModel: judgeProvider == null ? null : judgeModelId,
    );

    bloc.add(StartRun(
      tasks: selectedTasks,
      providers: selectedProviders,
      modelByProvider: modelMap,
      evaluatorConfig: evaluatorConfig,
      name: _label.trim().isEmpty ? null : _label.trim(),
    ));

    if (!mounted) return;
    final goRouter = GoRouter.of(context);
    goRouter.push('/run', extra: bloc);
  }
}

class _LabelField extends StatelessWidget {
  const _LabelField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Label this run (optional)',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.registry,
    required this.selected,
    required this.onChanged,
  });

  final TaskRegistry registry;
  final Set<String> selected;
  final void Function(String taskId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final byCategory = <Category, List<BenchmarkTask>>{};
    for (final t in registry.all()) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tasks',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final category in byCategory.keys) ...[
          Text(
            category.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final t in byCategory[category]!)
            CheckboxListTile(
              value: selected.contains(t.id),
              title: Text(t.id),
              onChanged: (v) => onChanged(t.id, v ?? false),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ProviderRow extends StatefulWidget {
  const _ProviderRow({
    required this.provider,
    required this.checked,
    required this.onChecked,
    required this.onModelChanged,
  });
  final ModelProvider provider;
  final bool checked;
  final ValueChanged<bool> onChecked;
  final ValueChanged<String> onModelChanged;

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  Future<List<String>>? _modelsFuture;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(widget.provider.displayName),
          value: widget.checked,
          onChanged: (v) {
            setState(() {
              widget.onChecked(v ?? false);
              _modelsFuture ??= widget.provider.listModels();
            });
          },
        ),
        if (widget.checked)
          Padding(
            padding:
                const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: FutureBuilder<List<String>>(
              future: _modelsFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError ||
                    snap.data == null ||
                    snap.data!.isEmpty) {
                  return TextField(
                    decoration: const InputDecoration(
                      labelText: 'Model id',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: widget.onModelChanged,
                  );
                }
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  items: snap.data!
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) widget.onModelChanged(v);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
