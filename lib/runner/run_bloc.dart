import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
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
  }) : super(const RunIdle()) {
    on<StartRun>(_onStart);
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
    final runId = idGenerator();
    final total = event.tasks.length * event.providers.length;
    var completed = 0;
    final results = <TaskRunResult>[];

    await runDao.startRun(runId: runId, startedAt: now());
    emit(RunInProgress(
      runId: runId,
      completed: 0,
      total: total,
      results: const [],
    ));

    try {
      for (final task in event.tasks) {
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
          final responseWithCode = copyWithCode(response, extracted);

          // Show model output while evaluators run
          emit(RunInProgress(
            runId: runId,
            completed: completed,
            total: total,
            results: List.unmodifiable(results),
            currentLabel:
                'Evaluating ${provider.displayName} on ${task.id}…',
            currentRawResponse: response.rawText,
          ));

          final dir = await workdirManager.createTaskWorkdir(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            fixtures: task.fixtures,
            generatedCode: extracted,
            generatedCodePath: task.generatedCodePath,
          );

          final evaluations = <EvaluationResult>[];
          for (final evaluator in task.evaluatorsFor(const EvaluatorConfig())) {
            final result = await evaluator.evaluate(
              EvaluationContext(
                workDir: dir,
                response: responseWithCode,
                task: task,
              ),
            );
            evaluations.add(result);
          }

          final aggregate = evaluations.isEmpty
              ? 0.0
              : evaluations.map((e) => e.score).reduce((a, b) => a + b) /
                  evaluations.length;

          final result = TaskRunResult(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            response: responseWithCode,
            evaluations: evaluations,
            aggregateScore: aggregate,
            completedAt: now(),
          );
          results.add(result);
          await runDao.persistTaskRun(result);
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

ModelResponse copyWithCode(ModelResponse r, String? code) => ModelResponse(
      rawText: r.rawText,
      extractedCode: code,
      promptTokens: r.promptTokens,
      completionTokens: r.completionTokens,
      latency: r.latency,
    );
