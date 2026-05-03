import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:equatable/equatable.dart';

class RunSummary extends Equatable {
  const RunSummary({
    required this.run,
    required this.taskRuns,
    required this.evaluationsByTaskRunId,
  });

  final Run run;
  final List<TaskRun> taskRuns;
  final Map<String, List<Evaluation>> evaluationsByTaskRunId;

  @override
  List<Object?> get props => [run, taskRuns, evaluationsByTaskRunId];
}

extension RunSummaryLoader on RunDao {
  Future<RunSummary?> loadSummary(String runId) async {
    final run = await runById(runId);
    if (run == null) return null;
    final trs = await taskRunsForRun(runId);
    final evals = <String, List<Evaluation>>{};
    for (final tr in trs) {
      evals[tr.id] = await evaluationsForTaskRun(tr.id);
    }
    return RunSummary(
      run: run,
      taskRuns: trs,
      evaluationsByTaskRunId: evals,
    );
  }
}
