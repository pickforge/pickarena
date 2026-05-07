import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/core/unified_diff.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/widgets/diff_view.dart';
import 'package:dart_arena/ui/widgets/evaluator_card.dart';
import 'package:dart_arena/ui/widgets/score_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TaskRunDetailsPage extends StatefulWidget {
  const TaskRunDetailsPage({
    super.key,
    required this.runId,
    required this.taskRunId,
    this.dao,
    this.registry,
  });

  final String runId;
  final String taskRunId;
  final RunDao? dao;
  final TaskRegistry? registry;

  @override
  State<TaskRunDetailsPage> createState() => _TaskRunDetailsPageState();
}

class _TaskRunDetailsPageState extends State<TaskRunDetailsPage> {
  late final RunDao _dao;
  late final TaskRegistry _registry;
  Future<_TaskRunBundle?>? _future;

  @override
  void initState() {
    super.initState();
    _dao = widget.dao ?? context.read<RunDao>();
    _registry = widget.registry ?? buildDefaultTaskRegistry();
    _future = _load();
  }

  Future<_TaskRunBundle?> _load() async {
    final tr = await _dao.taskRunById(widget.taskRunId);
    if (tr == null) return null;
    final evals = await _dao.evaluationsForTaskRun(tr.id);
    final task = _registry.byId(tr.taskId);
    return _TaskRunBundle(taskRun: tr, evaluations: evals, task: task);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task run')),
      body: FutureBuilder<_TaskRunBundle?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snap.data;
          if (bundle == null) {
            return const Center(child: Text('Task run not found.'));
          }
          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                _Header(bundle: bundle),
                _ScoreStrip(evaluations: bundle.evaluations),
                const TabBar(
                  tabs: [
                    Tab(text: 'Output'),
                    Tab(text: 'Diff'),
                    Tab(text: 'Evaluations'),
                    Tab(text: 'Prompt'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OutputTab(taskRun: bundle.taskRun),
                      _DiffTab(bundle: bundle),
                      _EvaluationsTab(evaluations: bundle.evaluations),
                      _PromptTab(task: bundle.task),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskRunBundle {
  const _TaskRunBundle({
    required this.taskRun,
    required this.evaluations,
    required this.task,
  });
  final TaskRun taskRun;
  final List<Evaluation> evaluations;
  final BenchmarkTask? task;
}

class _Header extends StatelessWidget {
  const _Header({required this.bundle});
  final _TaskRunBundle bundle;

  @override
  Widget build(BuildContext context) {
    final tr = bundle.taskRun;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tr.providerId} / ${tr.modelId} / ${tr.taskId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${tr.completedAt.toIso8601String()} \u00b7 agg ',
                ),
                WidgetSpan(
                  child: Text(
                    tr.aggregateScore.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextSpan(
                  text:
                      '\u00b7 ${tr.latencyMs}ms '
                      '\u00b7 ${tr.promptTokens ?? '?'}/${tr.completionTokens ?? '?'} '
                      'tokens',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.evaluations});
  final List<Evaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: evaluations
            .map((e) => ScoreChip(evaluatorId: e.evaluatorId, score: e.score))
            .toList(),
      ),
    );
  }
}

class _OutputTab extends StatefulWidget {
  const _OutputTab({required this.taskRun});
  final TaskRun taskRun;

  @override
  State<_OutputTab> createState() => _OutputTabState();
}

class _OutputTabState extends State<_OutputTab> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final tr = widget.taskRun;
    final raw = tr.responseText;
    final extracted = _extractDart(raw) ?? raw;
    final shown = _showRaw ? raw : extracted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Extracted code')),
                  ButtonSegment(value: true, label: Text('Raw output')),
                ],
                selected: {_showRaw},
                onSelectionChanged: (s) => setState(() => _showRaw = s.first),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shown));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              shown,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  String? _extractDart(String raw) {
    final dart = RegExp(r'```dart\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (dart != null) return '${dart.group(1)!}\n';
    final any = RegExp(r'```\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (any != null) return '${any.group(1)!}\n';
    return null;
  }
}

class _DiffTab extends StatelessWidget {
  const _DiffTab({required this.bundle});
  final _TaskRunBundle bundle;

  @override
  Widget build(BuildContext context) {
    final task = bundle.task;
    if (task == null) {
      return const Center(
        child: Text('Task no longer registered; no original to diff against.'),
      );
    }
    final original = task.fixtures[task.generatedCodePath];
    if (original == null) {
      return const Center(
        child: Text('Task has no original at this path to diff against.'),
      );
    }
    final extracted =
        _extractDart(bundle.taskRun.responseText) ??
        bundle.taskRun.responseText;
    final lines = computeUnifiedDiff(original, extracted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy diff',
            onPressed: () {
              final buf = StringBuffer();
              for (final l in lines) {
                final prefix = switch (l.kind) {
                  DiffLineKind.added => '+',
                  DiffLineKind.removed => '-',
                  DiffLineKind.context => ' ',
                };
                buf.write('$prefix ${l.text}');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
            },
          ),
        ),
        Expanded(child: DiffView(lines: lines)),
      ],
    );
  }

  String? _extractDart(String raw) {
    final dart = RegExp(r'```dart\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (dart != null) return '${dart.group(1)!}\n';
    final any = RegExp(r'```\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (any != null) return '${any.group(1)!}\n';
    return null;
  }
}

class _EvaluationsTab extends StatelessWidget {
  const _EvaluationsTab({required this.evaluations});
  final List<Evaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    if (evaluations.isEmpty) {
      return const Center(child: Text('No evaluations recorded.'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: evaluations.map((e) => EvaluatorCard(evaluation: e)).toList(),
    );
  }
}

class _PromptTab extends StatelessWidget {
  const _PromptTab({required this.task});
  final BenchmarkTask? task;

  @override
  Widget build(BuildContext context) {
    if (task == null) {
      return const Center(
        child: Text('Task no longer registered; prompt unavailable.'),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prompt', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(task!.prompt),
          if (task!.judgeRubric != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Judge rubric'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SelectableText(task!.judgeRubric!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
