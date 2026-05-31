import 'dart:async';

import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/failed_combo_snapshot.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RunProgressPage extends StatelessWidget {
  const RunProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunBloc, RunState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Run'),
            actions: switch (state) {
              RunInProgress(
                :final runId,
                :final failed,
                :final pending,
                :final active,
              )
                  when failed.isNotEmpty && pending == 0 && active.isEmpty =>
                [
                  TextButton(
                    onPressed: () =>
                        context.read<RunBloc>().add(FinishRun(runId)),
                    child: const Text('Finish run'),
                  ),
                ],
              _ => null,
            },
          ),
          body: switch (state) {
            RunIdle() => const Center(child: Text('idle')),
            RunInProgress(
              :final runId,
              :final completed,
              :final total,
              :final active,
              :final results,
              :final pending,
              :final failed,
            ) =>
              _ProgressView(
                runId: runId,
                completed: completed,
                total: total,
                active: active,
                results: results,
                pending: pending,
                failed: failed,
              ),
            RunCompleted(:final results) => ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) => _ResultCard(result: results[i]),
            ),
            RunFailed(:final error) => _FatalFailedView(error: error),
          },
        );
      },
    );
  }
}

class _FatalFailedView extends StatelessWidget {
  const _FatalFailedView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.runId,
    required this.completed,
    required this.total,
    required this.active,
    required this.results,
    required this.pending,
    required this.failed,
  });

  final String runId;
  final int completed;
  final int total;
  final List<RunProgressSnapshot> active;
  final List<TaskRunResult> results;
  final int pending;
  final List<FailedComboSnapshot> failed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: total == 0 ? null : completed / total),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '$completed / $total completed',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        if (pending > 0)
          Center(
            child: Text(
              '$pending queued',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        if (active.isEmpty && completed < total)
          const Center(child: CircularProgressIndicator()),
        ...active.map((s) => _ActiveCard(snapshot: s)),
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Failed (${failed.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          ...failed.map(
            (f) => _FailedCard(
              snapshot: f,
              onRetry: () => context.read<RunBloc>().add(
                RetryCombo(runId: runId, failedIndex: f.index),
              ),
            ),
          ),
        ],
        if (results.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Completed',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...results.map((r) => _ResultCard(result: r)),
        ],
      ],
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.snapshot, required this.onRetry});

  final FailedComboSnapshot snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            title: Text(snapshot.label),
            subtitle: SelectableText(
              snapshot.errorMessage,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ),
          if (snapshot.stackTrace != null)
            ExpansionTile(
              title: const Text('Stack trace', style: TextStyle(fontSize: 13)),
              dense: true,
              childrenPadding: const EdgeInsets.all(12),
              children: [
                SelectableText(
                  snapshot.stackTrace!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.snapshot});

  final RunProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snapshot.label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _phaseLabel(snapshot.phase),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                _ElapsedText(startedAt: snapshot.startedAt),
              ],
            ),
            if (snapshot.promptTokens != null ||
                snapshot.completionTokens != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tokens: ${snapshot.promptTokens ?? '?'} in / ${snapshot.completionTokens ?? '?'} out',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            ExpansionTile(
              key: PageStorageKey('thinking-${snapshot.index}'),
              title: const Text('Thinking', style: TextStyle(fontSize: 13)),
              dense: true,
              childrenPadding: const EdgeInsets.all(12),
              children: [
                Text(
                  snapshot.reasoningPreview.isEmpty
                      ? 'No thinking stream available yet.'
                      : snapshot.reasoningPreview,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
            ExpansionTile(
              key: PageStorageKey('answer-${snapshot.index}'),
              title: const Text('Answer', style: TextStyle(fontSize: 13)),
              dense: true,
              childrenPadding: const EdgeInsets.all(12),
              children: [
                Text(
                  snapshot.answerPreview.isEmpty
                      ? 'Waiting for answer...'
                      : snapshot.answerPreview,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _phaseLabel(RunComboPhase phase) => switch (phase) {
  RunComboPhase.queued => 'Queued',
  RunComboPhase.requestingModel => 'Requesting model...',
  RunComboPhase.streamingResponse => 'Streaming response...',
  RunComboPhase.extractingCode => 'Extracting code...',
  RunComboPhase.creatingWorkdir => 'Creating workdir...',
  RunComboPhase.preparingWorkspace => 'Preparing workspace...',
  RunComboPhase.runningAgent => 'Running agent...',
  RunComboPhase.capturingPatch => 'Capturing patch...',
  RunComboPhase.grading => 'Grading final workspace...',
  RunComboPhase.preparing => 'Preparing...',
  RunComboPhase.evaluating => 'Evaluating...',
  RunComboPhase.persisting => 'Persisting...',
};

class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final d = DateTime.now().difference(widget.startedAt);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final label = h > 0
        ? '${h}h ${m}m ${s}s'
        : m > 0
        ? '${m}m ${s}s'
        : '${s}s';
    if (label != _label) {
      setState(() => _label = label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.result});
  final TaskRunResult result;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final evaluations = r.evaluations;
    final allPassed = evaluations.every((e) => e.passed);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          ListTile(
            title: Text('${r.providerId} / ${r.modelId}'),
            subtitle: Text(
              '${r.taskId} — Score: ${r.aggregateScore.toStringAsFixed(2)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allPassed ? Icons.check_circle : Icons.error,
                  color: allPassed ? Colors.green : Colors.red,
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Evaluations:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...evaluations.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            e.passed ? Icons.check : Icons.close,
                            size: 16,
                            color: e.passed ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.evaluatorId} (${e.score.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (e.rationale != null &&
                                    e.rationale!.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: SelectableText(
                                      e.rationale!,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (r.response.extractedCode != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Extracted code:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        r.response.extractedCode as String,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Latency: ${r.response.latency.inMilliseconds}ms'
                    ' | Tokens: ${r.response.promptTokens ?? '?'} in'
                    ' / ${r.response.completionTokens ?? '?'} out',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
