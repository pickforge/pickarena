import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/current_platform.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/runner/start_run_config.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/widgets/task_metadata_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  final Map<String, Set<String>> _models = {};
  final Set<String> _selectedTaskIds = {};
  final _labelController = TextEditingController();
  late final TaskPlatform _hostPlatform;
  Category? _categoryFilter;
  BenchmarkTrack? _trackFilter;
  TaskDifficulty? _difficultyFilter;
  TaskTag? _tagFilter;
  bool _loading = true;
  bool _useReferencePlan = false;
  int _maxConcurrency = 4;

  @override
  void initState() {
    super.initState();
    _registry = widget.registry ?? buildDefaultTaskRegistry();
    _hostPlatform = currentTaskPlatform();
    for (final t in _registry.all()) {
      if (t.supportsPlatform(_hostPlatform)) {
        _selectedTaskIds.add(t.id);
      }
    }
    if (widget.providers != null) {
      _providers = widget.providers!;
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProviders();
      });
    }
  }

  Future<void> _loadProviders() async {
    final settings = context.read<SettingsRepository>();
    final results = await Future.wait([
      buildEnabledProviders(settings),
      settings.getRunConcurrency(),
    ]);
    if (!mounted) return;
    setState(() {
      _providers = results[0] as List<ModelProvider>;
      _maxConcurrency = results[1] as int;
      _loading = false;
    });
  }

  int get _comboCount {
    var count = 0;
    for (final p in _providers) {
      if (_checkedProvider[p.id] != true) continue;
      final set = _models[p.id];
      if (set == null || set.isEmpty) continue;
      count += set.length;
    }
    return count * _selectedTaskIds.length;
  }

  int get _pairCount {
    var count = 0;
    for (final p in _providers) {
      if (_checkedProvider[p.id] != true) continue;
      final set = _models[p.id];
      if (set == null || set.isEmpty) continue;
      count += set.length;
    }
    return count;
  }

  bool get _canRun {
    if (_selectedTaskIds.isEmpty) return false;
    final selectedTasks = _registry
        .all()
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();
    if (selectedTasks.any((t) => !t.supportsPlatform(_hostPlatform))) {
      return false;
    }
    final selectedProviders = _providers
        .where((p) => _checkedProvider[p.id] == true)
        .toList();
    final hasAgenticTask = selectedTasks.any(
      (t) => t.track == BenchmarkTrack.agentic,
    );
    if (hasAgenticTask &&
        selectedProviders.every((p) => p.mode != ProviderMode.agent)) {
      return false;
    }
    for (final p in _providers) {
      if (_checkedProvider[p.id] != true) continue;
      final set = _models[p.id];
      if (set == null || set.isEmpty) return false;
    }
    if (selectedProviders.isEmpty) return false;
    return true;
  }

  bool get _agenticNeedsHarness {
    final selectedTasks = _registry
        .all()
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();
    if (!selectedTasks.any((t) => t.track == BenchmarkTrack.agentic)) {
      return false;
    }
    final selectedProviders = _providers
        .where((p) => _checkedProvider[p.id] == true)
        .toList();
    return selectedProviders.every((p) => p.mode != ProviderMode.agent);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
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
                      _LabelField(controller: _labelController),
                      const SizedBox(height: 16),
                      _TaskPicker(
                        registry: _registry,
                        selected: _selectedTaskIds,
                        hostPlatform: _hostPlatform,
                        categoryFilter: _categoryFilter,
                        trackFilter: _trackFilter,
                        difficultyFilter: _difficultyFilter,
                        tagFilter: _tagFilter,
                        onCategoryFilterChanged: (v) =>
                            setState(() => _categoryFilter = v),
                        onTrackFilterChanged: (v) =>
                            setState(() => _trackFilter = v),
                        onDifficultyFilterChanged: (v) =>
                            setState(() => _difficultyFilter = v),
                        onTagFilterChanged: (v) =>
                            setState(() => _tagFilter = v),
                        onChanged: (id, v) => setState(() {
                          if (v) {
                            _selectedTaskIds.add(id);
                          } else {
                            _selectedTaskIds.remove(id);
                          }
                        }),
                      ),
                      const SizedBox(height: 8),
                      _PlanToggle(
                        registry: _registry,
                        selectedTaskIds: _selectedTaskIds,
                        value: _useReferencePlan,
                        onChanged: (v) => setState(() => _useReferencePlan = v),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Providers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ..._providers.map(
                        (provider) => _ProviderRow(
                          provider: provider,
                          checked: _checkedProvider[provider.id] ?? false,
                          selectedModels: _models[provider.id] ?? const {},
                          onChecked: (v) => setState(() {
                            _checkedProvider[provider.id] = v;
                          }),
                          onModelSelectionChanged: (set) => setState(() {
                            _models[provider.id] = set;
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_comboCount > 0)
                        Text(
                          'Will run $_pairCount (provider, model) pairs'
                          ' × ${_selectedTaskIds.length} tasks'
                          ' = $_comboCount combos'
                          ', ≈ $_maxConcurrency× parallel',
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (_agenticNeedsHarness)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Agentic tasks require a configured agent harness provider.',
                            style: TextStyle(fontSize: 13, color: Colors.red),
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
    final selectedProviders = _providers
        .where((p) => _checkedProvider[p.id] == true)
        .toList();
    final modelsByProvider = <String, List<String>>{};
    for (final p in selectedProviders) {
      final set = _models[p.id];
      if (set != null && set.isNotEmpty) {
        modelsByProvider[p.id] = set.toList();
      }
    }
    final selectedTasks = _registry
        .all()
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();

    final settings = context.read<SettingsRepository>();

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

    final weights = await _safeWeights(settings);

    if (!mounted) return;
    final goRouter = GoRouter.of(context);
    goRouter.push(
      '/run',
      extra: StartRunConfig(
        tasks: selectedTasks,
        providers: selectedProviders,
        modelsByProvider: modelsByProvider,
        evaluatorConfig: evaluatorConfig,
        weights: weights,
        useReferencePlan: _useReferencePlan,
        name: _labelController.text.trim().isEmpty
            ? null
            : _labelController.text.trim(),
        maxConcurrency: _maxConcurrency,
      ),
    );
  }

  Future<Map<String, double>> _safeWeights(SettingsRepository repo) async {
    try {
      return await repo.getEvaluatorWeights();
    } catch (e, st) {
      debugPrint('Failed to load evaluator weights: $e\n$st');
      return const {};
    }
  }
}

class _LabelField extends StatelessWidget {
  const _LabelField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Label this run (optional)',
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.registry,
    required this.selected,
    required this.hostPlatform,
    required this.categoryFilter,
    required this.trackFilter,
    required this.difficultyFilter,
    required this.tagFilter,
    required this.onCategoryFilterChanged,
    required this.onTrackFilterChanged,
    required this.onDifficultyFilterChanged,
    required this.onTagFilterChanged,
    required this.onChanged,
  });

  final TaskRegistry registry;
  final Set<String> selected;
  final TaskPlatform hostPlatform;
  final Category? categoryFilter;
  final BenchmarkTrack? trackFilter;
  final TaskDifficulty? difficultyFilter;
  final TaskTag? tagFilter;
  final ValueChanged<Category?> onCategoryFilterChanged;
  final ValueChanged<BenchmarkTrack?> onTrackFilterChanged;
  final ValueChanged<TaskDifficulty?> onDifficultyFilterChanged;
  final ValueChanged<TaskTag?> onTagFilterChanged;
  final void Function(String taskId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final byCategory = <Category, List<BenchmarkTask>>{};
    final filtered = registry.query(
      category: categoryFilter,
      track: trackFilter,
      difficulty: difficultyFilter,
      tags: tagFilter == null ? const {} : {tagFilter!},
    );
    for (final t in filtered) {
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownButton<Category?>(
              key: const Key('task-category-filter'),
              value: categoryFilter,
              hint: const Text('All categories'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All categories'),
                ),
                for (final category in Category.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: onCategoryFilterChanged,
            ),
            DropdownButton<BenchmarkTrack?>(
              key: const Key('task-track-filter'),
              value: trackFilter,
              hint: const Text('All tracks'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All tracks')),
                for (final track in BenchmarkTrack.values)
                  DropdownMenuItem(value: track, child: Text(track.label)),
              ],
              onChanged: onTrackFilterChanged,
            ),
            DropdownButton<TaskDifficulty?>(
              key: const Key('task-difficulty-filter'),
              value: difficultyFilter,
              hint: const Text('All difficulties'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All difficulties'),
                ),
                for (final difficulty in TaskDifficulty.values)
                  if (difficulty != TaskDifficulty.unspecified)
                    DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty.label),
                    ),
              ],
              onChanged: onDifficultyFilterChanged,
            ),
            DropdownButton<TaskTag?>(
              key: const Key('task-tag-filter'),
              value: tagFilter,
              hint: const Text('All tags'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All tags')),
                for (final tag in TaskTag.values)
                  DropdownMenuItem(value: tag, child: Text(tag.label)),
              ],
              onChanged: onTagFilterChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (byCategory.isEmpty)
          const Text('No tasks match the current filters.'),
        for (final category in byCategory.keys) ...[
          Text(
            category.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final t in byCategory[category]!)
            _TaskRow(
              task: t,
              selected: selected.contains(t.id),
              supported: t.supportsPlatform(hostPlatform),
              onChanged: (v) => onChanged(t.id, v),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.selected,
    required this.supported,
    required this.onChanged,
  });

  final BenchmarkTask task;
  final bool selected;
  final bool supported;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final showMetadata =
        task.tags.isNotEmpty ||
        task.difficulty != TaskDifficulty.unspecified ||
        task.platformRequirements.isNotEmpty ||
        task.timeout != null ||
        task.track != BenchmarkTrack.codegen ||
        task.version != 1;
    return CheckboxListTile(
      dense: true,
      value: selected && supported,
      title: Text(task.id),
      subtitle: showMetadata || !supported
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showMetadata) TaskMetadataChips(task: task, compact: true),
                if (!supported)
                  const Text(
                    'Unsupported on this host platform; skipped for new runs.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            )
          : null,
      onChanged: supported ? (v) => onChanged(v ?? false) : null,
    );
  }
}

class _ProviderRow extends StatefulWidget {
  const _ProviderRow({
    required this.provider,
    required this.checked,
    required this.selectedModels,
    required this.onChecked,
    required this.onModelSelectionChanged,
  });
  final ModelProvider provider;
  final bool checked;
  final Set<String> selectedModels;
  final ValueChanged<bool> onChecked;
  final ValueChanged<Set<String>> onModelSelectionChanged;

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow>
    with AutomaticKeepAliveClientMixin {
  Future<List<ModelInfo>>? _modelsFuture;
  final _freeformController = TextEditingController();
  final _freeformFocus = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _freeformController.dispose();
    _freeformFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final checked = widget.checked;
    return Column(
      children: [
        CheckboxListTile(
          title: Text(widget.provider.displayName),
          value: checked,
          onChanged: (v) {
            final isChecked = v ?? false;
            widget.onChecked(isChecked);
            if (isChecked) {
              _modelsFuture ??= widget.provider.listModels();
            }
          },
        ),
        if (checked)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: FutureBuilder<List<ModelInfo>>(
              future: _modelsFuture,
              builder: (context, snap) {
                if (!checked) return const SizedBox.shrink();
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
                  return _FreeformChipInput(
                    controller: _freeformController,
                    focusNode: _freeformFocus,
                    selected: widget.selectedModels,
                    onChanged: widget.onModelSelectionChanged,
                  );
                }
                if (widget.provider.mode == ProviderMode.agent) {
                  return Column(
                    children: [
                      _ListedChipSelector(
                        listedModels: snap.data!,
                        selected: widget.selectedModels,
                        onChanged: widget.onModelSelectionChanged,
                      ),
                      const SizedBox(height: 8),
                      _FreeformChipInput(
                        controller: _freeformController,
                        focusNode: _freeformFocus,
                        selected: widget.selectedModels,
                        onChanged: widget.onModelSelectionChanged,
                      ),
                    ],
                  );
                }
                return _ListedChipSelector(
                  listedModels: snap.data!,
                  selected: widget.selectedModels,
                  onChanged: widget.onModelSelectionChanged,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ListedChipSelector extends StatelessWidget {
  const _ListedChipSelector({
    required this.listedModels,
    required this.selected,
    required this.onChanged,
  });
  final List<ModelInfo> listedModels;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final flatIds = <String>[];
    for (final info in listedModels) {
      if (info.efforts.isEmpty) {
        flatIds.add(info.id);
      } else {
        for (final effort in info.efforts) {
          flatIds.add('${info.id}::$effort');
        }
      }
    }
    final deduped = flatIds.toSet().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => onChanged(deduped.toSet()),
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: () => onChanged({}),
              child: const Text('Clear'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: deduped.map((m) {
            final isSelected = selected.contains(m);
            return FilterChip(
              label: Text(m),
              selected: isSelected,
              onSelected: (v) {
                final updated = selected.toSet();
                if (v) {
                  updated.add(m);
                } else {
                  updated.remove(m);
                }
                onChanged(updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FreeformChipInput extends StatefulWidget {
  const _FreeformChipInput({
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_FreeformChipInput> createState() => _FreeformChipInputState();
}

class _FreeformChipInputState extends State<_FreeformChipInput>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chips = widget.selected.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: InputDecoration(
            labelText: 'Custom model ids (comma-separated)',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
              onPressed: _commit,
            ),
          ),
          onSubmitted: (_) => _commit(),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: chips.map((m) {
              return Chip(
                label: Text(m),
                onDeleted: () {
                  final updated = widget.selected.toSet()..remove(m);
                  widget.onChanged(updated);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _commit() {
    final raw = widget.controller.text;
    if (raw.trim().isEmpty) return;
    final parts = raw.split(',');
    final updated = widget.selected.toSet();
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty) updated.add(trimmed);
    }
    widget.controller.clear();
    widget.onChanged(updated);
  }
}

class _PlanToggle extends StatelessWidget {
  const _PlanToggle({
    required this.registry,
    required this.selectedTaskIds,
    required this.value,
    required this.onChanged,
  });

  final TaskRegistry registry;
  final Set<String> selectedTaskIds;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = registry
        .all()
        .where((t) => selectedTaskIds.contains(t.id))
        .toList();
    final withPlan = selected.where((t) => t.hasReferencePlan).length;
    final canEnable = withPlan > 0;
    final label = canEnable
        ? 'Use reference plan ($withPlan of ${selected.length} selected tasks)'
        : 'Use reference plan';
    return SwitchListTile(
      title: Text(label),
      subtitle: canEnable
          ? const Text(
              'Inject a curated plan into the prompt to isolate execution skill from planning skill.',
              style: TextStyle(fontSize: 12),
            )
          : const Text(
              'Select a planning task to enable.',
              style: TextStyle(fontSize: 12),
            ),
      value: canEnable && value,
      onChanged: canEnable ? onChanged : null,
    );
  }
}
