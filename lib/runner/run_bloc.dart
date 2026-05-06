import 'dart:math';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_failure_policy.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _Combo {
  const _Combo({
    required this.index,
    required this.task,
    required this.provider,
    required this.modelId,
    required this.planId,
    required this.planMarkdown,
    required this.label,
  });

  final int index;
  final BenchmarkTask task;
  final ModelProvider provider;
  final String modelId;
  final String? planId;
  final String? planMarkdown;
  final String label;
}

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc({
    required this.workdirManager,
    required this.runDao,
    required this.now,
    required this.idGenerator,
    this.weights = defaultEvaluatorWeights,
    this.planDao,
  }) : super(const RunIdle()) {
    on<StartRun>(_onStart);
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;
  final Map<String, double> weights;
  final PlanDao? planDao;

  static const _maxPreviewChars = 16 * 1024;

  String _trimPreview(String value) {
    if (value.length <= _maxPreviewChars) return value;
    return value.substring(value.length - _maxPreviewChars);
  }

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
    final runId = event.existingRunId ?? idGenerator();

    final normalizedModels = <String, List<String>>{};
    for (final provider in event.providers) {
      final models = event.modelsByProvider[provider.id];
      if (models == null) continue;
      final seen = <String>{};
      final deduped = <String>[];
      for (final m in models) {
        final trimmed = m.trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(trimmed)) deduped.add(trimmed);
      }
      if (deduped.isEmpty) {
        emit(RunFailed('No models selected for ${provider.id}'));
        return;
      }
      normalizedModels[provider.id] = deduped;
    }

    final combos = <_Combo>[];
    var idx = 0;
    for (final task in event.tasks) {
      for (final provider in event.providers) {
        final models = normalizedModels[provider.id];
        if (models == null) continue;
        for (final modelId in models) {
          combos.add(
            _Combo(
              index: idx,
              task: task,
              provider: provider,
              modelId: modelId,
              planId: null,
              planMarkdown: null,
              label: '${provider.displayName} / $modelId on ${task.id}',
            ),
          );
          idx++;
        }
      }
    }

    if (combos.isEmpty) {
      emit(const RunFailed('No benchmark combos selected'));
      return;
    }

    if (event.existingRunId == null) {
      await runDao.startRun(runId: runId, startedAt: now(), name: event.name);
    }
    emit(
      RunInProgress(
        runId: runId,
        completed: 0,
        total: combos.length,
        results: const [],
      ),
    );

    try {
      for (final task in event.tasks) {
        await task.ensureLoaded();
      }

      final planIdsByTask = <String, String?>{};
      final planMarkdownsByTask = <String, String?>{};
      if (event.useReferencePlan) {
        for (final task in event.tasks) {
          if (task.referencePlan != null) {
            planMarkdownsByTask[task.id] = task.referencePlan!.markdown;
            if (planDao != null) {
              planIdsByTask[task.id] = await planDao!.upsertReferencePlan(
                taskId: task.id,
                version: task.referencePlan!.version,
                artifact: task.referencePlan!.markdown,
              );
            }
          }
        }
      }

      for (var i = 0; i < combos.length; i++) {
        final cb = combos[i];
        final taskId = cb.task.id;
        combos[i] = _Combo(
          index: cb.index,
          task: cb.task,
          provider: cb.provider,
          modelId: cb.modelId,
          planId: planIdsByTask[taskId],
          planMarkdown: planMarkdownsByTask[taskId],
          label: cb.label,
        );
      }

      final resultSlots = List<TaskRunResult?>.filled(combos.length, null);
      final cap = event.maxConcurrency.clamp(1, 8);
      final active = <int, RunProgressSnapshot>{};
      Object? firstError;
      StartRun? retry;
      bool stopScheduling = false;

      void emitProgress() {
        if (emit.isDone) return;
        final sorted = active.values.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        emit(
          RunInProgress(
            runId: runId,
            completed: resultSlots.whereType<TaskRunResult>().length,
            total: combos.length,
            results: List.unmodifiable(resultSlots.whereType<TaskRunResult>()),
            active: List.unmodifiable(sorted),
          ),
        );
      }

      void updateActive(int index, RunProgressSnapshot snapshot) {
        active[index] = snapshot;
      }

      final sharedIterator = combos.iterator;

      Future<void> worker() async {
        while (true) {
          if (stopScheduling) return;

          final _Combo combo;
          if (sharedIterator.moveNext()) {
            combo = sharedIterator.current;
          } else {
            return;
          }

          updateActive(
            combo.index,
            RunProgressSnapshot(
              index: combo.index,
              label: combo.label,
              phase: RunComboPhase.requestingModel,
              startedAt: now(),
            ),
          );
          emitProgress();

          try {
            final result = await _runCombo(
              combo,
              runId,
              event.evaluatorConfig,
              active,
              updateActive,
              emitProgress,
            );
            await runDao.persistTaskRun(result);
            resultSlots[combo.index] = result;
          } catch (e, _) {
            if (event.onFailure == RunFailurePolicy.failFast) {
              firstError ??= e;
              retry ??= StartRun(
                tasks: [combo.task],
                providers: [combo.provider],
                modelsByProvider: {
                  combo.provider.id: [combo.modelId],
                },
                evaluatorConfig: event.evaluatorConfig,
                useReferencePlan: event.useReferencePlan,
                name: event.name,
                maxConcurrency: 1,
                onFailure: event.onFailure,
                existingRunId: runId,
              );
              stopScheduling = true;
              return;
            }
            final synthetic = TaskRunResult(
              runId: runId,
              providerId: combo.provider.id,
              modelId: combo.modelId,
              taskId: combo.task.id,
              response: const ModelResponse(
                rawText: '<error>',
                extractedCode: null,
                promptTokens: null,
                completionTokens: null,
                latency: Duration.zero,
              ),
              evaluations: [
                EvaluationResult(
                  evaluatorId: 'combo_failure',
                  passed: false,
                  score: 0.0,
                  rationale: 'combo failed during run: $e',
                  details: {'phase': 'run', 'error': '$e'},
                ),
              ],
              aggregateScore: 0.0,
              completedAt: now(),
              planId: combo.planId,
            );
            try {
              await runDao.persistTaskRun(synthetic);
            } catch (_) {
              stopScheduling = true;
              return;
            }
            resultSlots[combo.index] = synthetic;
          }

          active.remove(combo.index);
          emitProgress();

          if (resultSlots.whereType<TaskRunResult>().length == combos.length) {
            return;
          }
        }
      }

      final workerCount = min(cap, combos.length);
      final workers = List<Future<void>>.generate(workerCount, (_) => worker());
      await Future.wait(workers);

      if (firstError != null) {
        if (!emit.isDone) {
          emit(RunFailed('$firstError', retry: retry));
        }
        return;
      }

      await runDao.finishRun(runId, now());
      final finalResults = List<TaskRunResult>.unmodifiable(
        resultSlots.whereType<TaskRunResult>(),
      );
      if (!emit.isDone) {
        emit(RunCompleted(runId: runId, results: finalResults));
      }
    } catch (e, _) {
      if (!emit.isDone) {
        emit(RunFailed('$e'));
      }
    }
  }

  Future<TaskRunResult> _runCombo(
    _Combo combo,
    String runId,
    EvaluatorConfig evaluatorConfig,
    Map<int, RunProgressSnapshot> active,
    void Function(int, RunProgressSnapshot) updateActive,
    void Function() emitProgress,
  ) async {
    final task = combo.task;
    final provider = combo.provider;
    final modelId = combo.modelId;

    final prompt = buildPromptWithPlan(
      taskPrompt: task.prompt,
      planMarkdown: combo.planMarkdown,
    );

    ModelResponse response;

    if (provider is StreamingModelProvider) {
      final snapshot = active[combo.index];
      var reasoningPreview = snapshot?.reasoningPreview ?? '';
      var answerPreview = snapshot?.answerPreview ?? '';
      final rawBuf = StringBuffer();
      final stopwatch = Stopwatch()..start();
      int? pt;
      int? ct;

      updateActive(
        combo.index,
        (active[combo.index] ??
                RunProgressSnapshot(
                  index: combo.index,
                  label: combo.label,
                  phase: RunComboPhase.requestingModel,
                  startedAt: now(),
                ))
            .copyWith(phase: RunComboPhase.streamingResponse),
      );
      emitProgress();

      await for (final event in provider.generateStream(
        prompt: prompt,
        model: modelId,
        timeout: null,
      )) {
        switch (event) {
          case ModelStreamReasoningDelta(:final text):
            reasoningPreview = _trimPreview(reasoningPreview + text);
            updateActive(
              combo.index,
              active[combo.index]!.copyWith(reasoningPreview: reasoningPreview),
            );
            emitProgress();
          case ModelStreamContentDelta(:final text):
            answerPreview = _trimPreview(answerPreview + text);
            rawBuf.write(text);
            updateActive(
              combo.index,
              active[combo.index]!.copyWith(answerPreview: answerPreview),
            );
            emitProgress();
          case ModelStreamUsage(:final promptTokens, :final completionTokens):
            pt = promptTokens;
            ct = completionTokens;
            updateActive(
              combo.index,
              active[combo.index]!.copyWith(
                promptTokens: pt,
                completionTokens: ct,
              ),
            );
            emitProgress();
          case ModelStreamStarted():
          case ModelStreamCompleted():
            break;
        }
      }

      stopwatch.stop();
      response = ModelResponse(
        rawText: rawBuf.toString(),
        extractedCode: null,
        promptTokens: pt,
        completionTokens: ct,
        latency: stopwatch.elapsed,
      );
    } else {
      final snapshot = active[combo.index];
      updateActive(
        combo.index,
        (snapshot ??
                RunProgressSnapshot(
                  index: combo.index,
                  label: combo.label,
                  phase: RunComboPhase.requestingModel,
                  startedAt: now(),
                ))
            .copyWith(phase: RunComboPhase.requestingModel),
      );
      emitProgress();

      response = await provider.generate(prompt: prompt, model: modelId);

      updateActive(
        combo.index,
        active[combo.index]!.copyWith(
          answerPreview: _trimPreview(response.rawText),
          promptTokens: response.promptTokens,
          completionTokens: response.completionTokens,
          phase: RunComboPhase.extractingCode,
        ),
      );
      emitProgress();
    }

    updateActive(
      combo.index,
      active[combo.index]!.copyWith(phase: RunComboPhase.extractingCode),
    );
    emitProgress();

    final extracted = extractDartCode(response.rawText) ?? response.rawText;
    final responseWithCode = _copyWithCode(response, extracted);

    updateActive(
      combo.index,
      active[combo.index]!.copyWith(phase: RunComboPhase.creatingWorkdir),
    );
    emitProgress();

    final dir = await workdirManager.createTaskWorkdir(
      runId: runId,
      providerId: provider.id,
      modelId: modelId,
      taskId: task.id,
      fixtures: task.fixtures,
      generatedCode: extracted,
      generatedCodePath: task.generatedCodePath,
    );

    updateActive(
      combo.index,
      active[combo.index]!.copyWith(phase: RunComboPhase.preparing),
    );
    emitProgress();

    final evaluators = task.evaluatorsFor(evaluatorConfig);
    final prepResult = await workdirManager.prepare(
      dir,
      isFlutter: task.isFlutter,
    );
    final evaluations = <EvaluationResult>[];

    if (prepResult is PrepareFailed) {
      for (final evaluator in evaluators) {
        evaluations.add(
          EvaluationResult(
            evaluatorId: evaluator.id,
            passed: false,
            score: 0.0,
            rationale: 'prepare failed',
            details: {'stderr': prepResult.stderr},
          ),
        );
      }
    } else {
      updateActive(
        combo.index,
        active[combo.index]!.copyWith(phase: RunComboPhase.evaluating),
      );
      emitProgress();

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

    updateActive(
      combo.index,
      active[combo.index]!.copyWith(phase: RunComboPhase.persisting),
    );
    emitProgress();

    final aggregateScore = aggregate(evaluations, weights);

    return TaskRunResult(
      runId: runId,
      providerId: provider.id,
      modelId: modelId,
      taskId: task.id,
      response: responseWithCode,
      evaluations: evaluations,
      aggregateScore: aggregateScore,
      completedAt: now(),
      planId: combo.planId,
    );
  }
}

ModelResponse _copyWithCode(ModelResponse r, String? code) => ModelResponse(
  rawText: r.rawText,
  extractedCode: code,
  promptTokens: r.promptTokens,
  completionTokens: r.completionTokens,
  latency: r.latency,
);
