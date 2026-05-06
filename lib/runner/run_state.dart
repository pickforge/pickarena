import 'package:dart_arena/core/task_run_result.dart';
import 'package:equatable/equatable.dart';

sealed class RunState extends Equatable {
  const RunState();
  @override
  List<Object?> get props => [];
}

class RunIdle extends RunState {
  const RunIdle();
}

class RunInProgress extends RunState {
  const RunInProgress({
    required this.runId,
    required this.completed,
    required this.total,
    required this.results,
    this.currentLabels = const {},
  });

  final String runId;
  final int completed;
  final int total;
  final List<TaskRunResult> results;
  final Set<String> currentLabels;

  @override
  List<Object?> get props => [
        runId,
        completed,
        total,
        results,
        currentLabels,
      ];
}

class RunCompleted extends RunState {
  const RunCompleted({required this.runId, required this.results});

  final String runId;
  final List<TaskRunResult> results;

  @override
  List<Object?> get props => [runId, results];
}

class RunFailed extends RunState {
  const RunFailed(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}
