import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/failed_combo_snapshot.dart';
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
    this.pending = 0,
    this.failed = const [],
  });

  final String runId;
  final int completed;
  final int total;
  final List<TaskRunResult> results;
  final List<RunProgressSnapshot> active;
  final int pending;
  final List<FailedComboSnapshot> failed;

  @override
  List<Object?> get props => [
    runId,
    completed,
    total,
    results,
    active,
    pending,
    failed,
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
