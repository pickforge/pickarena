import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RunProgressPage extends StatelessWidget {
  const RunProgressPage({required this.bloc, super.key});
  final RunBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Run')),
        body: BlocBuilder<RunBloc, RunState>(
          builder: (context, state) {
            return switch (state) {
              RunIdle() => const Center(child: Text('idle')),
              RunInProgress(:final completed, :final total, :final currentLabel) =>
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$completed / $total'),
                      const SizedBox(height: 8),
                      Text(currentLabel ?? ''),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              RunCompleted(:final results) => ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final r = results[i];
                    return ListTile(
                      title: Text('${r.providerId} / ${r.modelId} / ${r.taskId}'),
                      subtitle: Text('Score: ${r.aggregateScore.toStringAsFixed(2)}'),
                    );
                  },
                ),
              RunFailed(:final error) =>
                Center(child: Text('Failed: $error')),
            };
          },
        ),
      ),
    );
  }
}
