import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
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
    this.active = const [],
  });

  final String runId;
  final int completed;
  final int total;
  final List<TaskRunResult> results;
  final List<RunProgressSnapshot> active;

  @override
  List<Object?> get props => [runId, completed, total, results, active];
}

class RunCompleted extends RunState {
  const RunCompleted({required this.runId, required this.results});

  final String runId;
  final List<TaskRunResult> results;

  @override
  List<Object?> get props => [runId, results];
}

class RunFailed extends RunState {
  const RunFailed(this.error, {this.retry});
  final String error;
  final StartRun? retry;

  @override
  List<Object?> get props => [error, retry];
}
