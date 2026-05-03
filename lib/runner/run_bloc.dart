import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc({
    required this.workdirManager,
    required this.runDao,
    required this.now,
    required this.idGenerator,
    this.weights = defaultEvaluatorWeights,
  }) : super(const RunIdle()) {
    on<StartRun>(_onStart);
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;
  final Map<String, double> weights;

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
    final runId = idGenerator();
    final total = event.tasks.length * event.providers.length;
    var completed = 0;
    final results = <TaskRunResult>[];

    await runDao.startRun(runId: runId, startedAt: now(), name: event.name);
    emit(RunInProgress(
      runId: runId,
      completed: 0,
      total: total,
      results: const [],
    ));

    try {
      for (final task in event.tasks) {
        await task.ensureLoaded();
        for (final provider in event.providers) {
          final modelId = event.modelByProvider[provider.id]!;
          emit(RunInProgress(
            runId: runId,
            completed: completed,
            total: total,
            results: List.unmodifiable(results),
            currentLabel: '${provider.displayName} on ${task.id}',
          ));

          final response = await provider.generate(
            prompt: task.prompt,
            model: modelId,
          );
          final extracted =
              extractDartCode(response.rawText) ?? response.rawText;
          final responseWithCode = _copyWithCode(response, extracted);

          final dir = await workdirManager.createTaskWorkdir(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            fixtures: task.fixtures,
            generatedCode: extracted,
            generatedCodePath: task.generatedCodePath,
          );

          final evaluators = task.evaluatorsFor(event.evaluatorConfig);
          final prepResult = await workdirManager.prepare(dir);
          final evaluations = <EvaluationResult>[];

          if (prepResult is PrepareFailed) {
            for (final evaluator in evaluators) {
              evaluations.add(EvaluationResult(
                evaluatorId: evaluator.id,
                passed: false,
                score: 0.0,
                rationale: 'prepare failed',
                details: {'stderr': prepResult.stderr},
              ));
            }
          } else {
            for (final evaluator in evaluators) {
              final result = await evaluator.evaluate(
                EvaluationContext(
                  workDir: dir,
                  response: responseWithCode,
                  task: task,
                ),
              );
              evaluations.add(result);
            }
          }

          final aggregateScore = aggregate(evaluations, weights);

          final taskResult = TaskRunResult(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            response: responseWithCode,
            evaluations: evaluations,
            aggregateScore: aggregateScore,
            completedAt: now(),
          );
          results.add(taskResult);
          await runDao.persistTaskRun(taskResult);
          completed++;
          emit(RunInProgress(
            runId: runId,
            completed: completed,
            total: total,
            results: List.unmodifiable(results),
          ));
        }
      }
      await runDao.finishRun(runId, now());
      emit(RunCompleted(runId: runId, results: List.unmodifiable(results)));
    } catch (e, _) {
      emit(RunFailed(e.toString()));
    }
  }
}

ModelResponse _copyWithCode(ModelResponse r, String? code) => ModelResponse(
      rawText: r.rawText,
      extractedCode: code,
      promptTokens: r.promptTokens,
      completionTokens: r.completionTokens,
      latency: r.latency,
    );
