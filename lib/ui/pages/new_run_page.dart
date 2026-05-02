import 'dart:io';

import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NewRunPage extends StatefulWidget {
  const NewRunPage({super.key});
  @override
  State<NewRunPage> createState() => _NewRunPageState();
}

class _NewRunPageState extends State<NewRunPage> {
  List<ModelProvider> _providers = [];
  final Map<String, bool> _checked = {};
  final Map<String, String> _models = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final p = await buildEnabledProviders(SettingsRepository());
    setState(() {
      _providers = p;
      _loading = false;
    });
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _providers.length,
                    itemBuilder: (context, i) => _ProviderRow(
                      provider: _providers[i],
                      checked: _checked[_providers[i].id] ?? false,
                      onChecked: (v) =>
                          setState(() => _checked[_providers[i].id] = v),
                      onModelChanged: (v) =>
                          _models[_providers[i].id] = v,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _startRun,
                      child: const Text('Run'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _startRun() async {
    final selected =
        _providers.where((p) => _checked[p.id] == true).toList();
    final modelMap = {
      for (final p in selected) p.id: _models[p.id] ?? '',
    };
    if (selected.isEmpty ||
        modelMap.values.any((m) => m.trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pick at least one provider + model')),
        );
      }
      return;
    }

    final docs = await getApplicationSupportDirectory();
    final root = Directory(p.join(docs.path, 'workdirs'))
      ..createSync(recursive: true);
    final db = AppDatabase();
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: root),
      runDao: RunDao(db),
      now: () => DateTime.now(),
      idGenerator: () =>
          'run-${DateTime.now().millisecondsSinceEpoch}',
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
      tasks: [OffByOnePaginationTask()],
      providers: selected,
      modelByProvider: modelMap,
      evaluatorConfig: evaluatorConfig,
    ));

    if (mounted) {
      final goRouter = GoRouter.of(context);
      goRouter.push('/run', extra: bloc);
    }
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
                    onChanged: (v) {
                      widget.onModelChanged(v);
                    },
                  );
                }
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  items: snap.data!
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m)))
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
