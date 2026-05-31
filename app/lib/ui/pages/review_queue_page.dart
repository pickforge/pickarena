import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/core/unified_diff.dart';
import 'package:dart_arena/review/review_battle.dart';
import 'package:dart_arena/review/review_repository.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/widgets/review_comparison_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReviewQueuePage extends StatefulWidget {
  const ReviewQueuePage({super.key, this.repository, this.registry});

  final ReviewRepository? repository;
  final TaskRegistry? registry;

  @override
  State<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends State<ReviewQueuePage> {
  late final ReviewRepository _repository;
  late final TaskRegistry _registry;
  Future<ReviewSelection?>? _future;
  bool _showReveal = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? context.read<ReviewRepository>();
    _registry = widget.registry ?? buildDefaultTaskRegistry();
    _load();
  }

  void _load() {
    setState(() {
      _showReveal = false;
      _future = _repository.nextBattle();
    });
  }

  Future<void> _submit(
    ReviewSelection selection,
    ReviewVote vote,
    String rationale,
  ) async {
    await _repository.submitVote(
      selection: selection,
      vote: vote,
      rationale: rationale,
    );
    if (!mounted) return;
    setState(() {
      _showReveal = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: FutureBuilder<ReviewSelection?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final selection = snap.data;
          if (selection == null) {
            return const _ColdStartPlaceholder();
          }
          final task = _registry.byId(selection.taskId);
          final bundle = ReviewComparisonBundle(
            taskTitle: task == null
                ? selection.taskId
                : '${task.category.label}: ${selection.taskId}',
            taskPrompt: task?.prompt ?? 'Task prompt unavailable.',
            benchmarkTrack: selection.benchmarkTrack,
            taskVersion: selection.taskVersion,
            left: _submissionData(
              label: 'A',
              taskRun: selection.left,
              task: task,
              evaluations: selection.leftEvaluations,
            ),
            right: _submissionData(
              label: 'B',
              taskRun: selection.right,
              task: task,
              evaluations: selection.rightEvaluations,
            ),
          );
          return ReviewComparisonView(
            bundle: bundle,
            showIdentityReveal: _showReveal,
            onNext: _load,
            onVote: (vote, rationale) => _submit(selection, vote, rationale),
          );
        },
      ),
    );
  }
}

class _ColdStartPlaceholder extends StatelessWidget {
  const _ColdStartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Need more comparable runs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Run at least two eligible submissions for the same task, task '
              'version, and benchmark track before starting blind review.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

ReviewSubmissionViewData _submissionData({
  required String label,
  required TaskRun taskRun,
  required BenchmarkTask? task,
  required List<Evaluation> evaluations,
}) {
  return ReviewSubmissionViewData(
    label: label,
    artifactTitle: taskRun.patchText == null ? 'Generated code/diff' : 'Patch',
    artifactText: _reviewArtifact(taskRun, task),
    correctnessLabel: 'Primary correctness: ${_primaryPassLabel(taskRun)}',
    evaluationSummary: _evaluationSummary(evaluations),
    providerId: taskRun.providerId,
    modelId: taskRun.modelId,
  );
}

String _reviewArtifact(TaskRun taskRun, BenchmarkTask? task) {
  final patch = taskRun.patchText;
  if (patch != null) return patch.isEmpty ? '(empty patch)' : patch;

  final generated =
      _extractCodeBlock(taskRun.responseText) ?? taskRun.responseText;
  final original = task == null ? null : task.fixtures[task.generatedCodePath];
  if (original == null) return generated;

  final diff = computeUnifiedDiff(original, generated);
  if (diff.isEmpty) return '(no diff)';
  return diff.map(_formatDiffLine).join();
}

String _formatDiffLine(DiffLine line) {
  final prefix = switch (line.kind) {
    DiffLineKind.added => '+',
    DiffLineKind.removed => '-',
    DiffLineKind.context => ' ',
  };
  return '$prefix ${line.text}';
}

String? _extractCodeBlock(String raw) {
  final dart = RegExp(r'```dart\s*\n([\s\S]*?)\n```').firstMatch(raw);
  if (dart != null) return '${dart.group(1)!}\n';
  final any = RegExp(r'```\s*\n([\s\S]*?)\n```').firstMatch(raw);
  if (any != null) return '${any.group(1)!}\n';
  return null;
}

String _primaryPassLabel(TaskRun taskRun) {
  return switch (taskRun.primaryPass) {
    true => 'pass',
    false => 'fail',
    null => 'unknown',
  };
}

String _evaluationSummary(List<Evaluation> evaluations) {
  if (evaluations.isEmpty) return '';
  final sorted = [...evaluations]
    ..sort((a, b) => a.evaluatorId.compareTo(b.evaluatorId));
  return sorted
      .map(
        (evaluation) =>
            '${evaluation.evaluatorId}: '
            '${evaluation.passed ? 'pass' : 'fail'} '
            '(${evaluation.score.toStringAsFixed(2)})',
      )
      .join(' · ');
}
