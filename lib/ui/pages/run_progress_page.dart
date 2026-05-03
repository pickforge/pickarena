import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RunProgressPage extends StatelessWidget {
  const RunProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run')),
      body: BlocBuilder<RunBloc, RunState>(
        builder: (context, state) {
          return switch (state) {
            RunIdle() => const Center(child: Text('idle')),
            RunInProgress(
              :final completed,
              :final total,
              :final currentLabel,
              :final currentRawResponse,
            ) =>
              _ProgressView(
                completed: completed,
                total: total,
                label: currentLabel,
                rawResponse: currentRawResponse,
              ),
            RunCompleted(:final results) =>
              ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) => _ResultCard(result: results[i]),
              ),
            RunFailed(:final error) =>
              Center(child: Text('Failed: $error')),
          };
        },
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.completed,
    required this.total,
    required this.label,
    required this.rawResponse,
  });

  final int completed;
  final int total;
  final String? label;
  final String? rawResponse;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                '$completed / $total',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(label ?? ''),
              const SizedBox(height: 16),
              if (rawResponse == null) const CircularProgressIndicator(),
            ],
          ),
        ),
        if (rawResponse != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const Text('Model output:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              rawResponse!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('Evaluating…')),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ],
    );
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
            subtitle: Text('${r.taskId} — Score: ${r.aggregateScore.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allPassed ? Icons.check_circle : Icons.error,
                  color: allPassed ? Colors.green : Colors.red,
                ),
                IconButton(
                  icon: Icon(_expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
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
                  const Text('Evaluations:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...evaluations.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            e.passed
                                ? Icons.check
                                : Icons.close,
                            size: 16,
                            color: e.passed
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.evaluatorId} (${e.score.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                if (e.rationale != null &&
                                    e.rationale!.isNotEmpty)
                                  Container(
                                    margin:
                                        const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius:
                                          BorderRadius.circular(4),
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
                    const Text('Extracted code:',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        r.response.extractedCode as String,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
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
