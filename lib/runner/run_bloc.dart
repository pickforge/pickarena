import 'dart:async';
import 'dart:collection';

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
import 'package:dart_arena/runner/failed_combo_snapshot.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:flutter/foundation.dart';
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
    on<RetryCombo>(_onRetry);
    on<FinishRun>(_onFinishRun);
  }

  @override
  Future<void> close() {
    for (final provider in _providers) {
      provider.dispose();
    }
    return super.close();
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;
  final Map<String, double> weights;
  final PlanDao? planDao;
  List<ModelProvider> _providers = const [];

  static const _maxPreviewChars = 16 * 1024;

  String _currentRunId = '';
  int _existingCount = 0;
  List<_Combo> _combos = [];
  List<TaskRunResult?> _resultSlots = [];
  final Map<int, FailedComboSnapshot> _failed = {};
  final Set<int> _retrying = {};
  final Queue<int> _pendingQueue = Queue<int>();
  final Map<int, RunProgressSnapshot> _active = {};
  int _runningWorkers = 0;
  int _maxConcurrency = 4;
  EvaluatorConfig _evaluatorConfig = const EvaluatorConfig();
  Completer<void>? _drainDone;

  String _trimPreview(String value) {
    if (value.length <= _maxPreviewChars) return value;
    return value.substring(value.length - _maxPreviewChars);
  }

  void _resetScheduler() {
    _currentRunId = '';
    _existingCount = 0;
    _combos = [];
    _resultSlots = [];
    _failed.clear();
    _retrying.clear();
    _pendingQueue.clear();
    _active.clear();
    _runningWorkers = 0;
    _maxConcurrency = 4;
    _evaluatorConfig = const EvaluatorConfig();
    _providers = const [];
    _drainDone = null;
  }

  void _emitProgress(Emitter<RunState> emit) {
    if (emit.isDone) return;
    final sortedActive = _active.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final failedList = _failed.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    emit(
      RunInProgress(
        runId: _currentRunId,
        completed:
            _existingCount + _resultSlots.whereType<TaskRunResult>().length,
        total: _existingCount + _combos.length,
        results: _buildVisibleResults(),
        active: List.unmodifiable(sortedActive),
        pending: _pendingQueue.length,
        failed: List.unmodifiable(failedList),
      ),
    );
  }

  List<TaskRunResult> _buildVisibleResults() {
    final out = <TaskRunResult>[];
    for (var i = 0; i < _resultSlots.length; i++) {
      final r = _resultSlots[i];
      if (r != null && !_failed.containsKey(i)) {
        out.add(r);
      }
    }
    return out;
  }

  void _ensureWorkers(Emitter<RunState> emit) {
    while (_runningWorkers < _maxConcurrency && _pendingQueue.isNotEmpty) {
      _runningWorkers++;
      unawaited(_worker(emit));
    }
  }

  Future<void> _worker(Emitter<RunState> emit) async {
    try {
      while (true) {
        if (emit.isDone) return;

        final int comboIndex;
        if (_pendingQueue.isNotEmpty) {
          comboIndex = _pendingQueue.removeFirst();
        } else {
          return;
        }
        final combo = _combos[comboIndex];

        _active[comboIndex] = RunProgressSnapshot(
          index: comboIndex,
          label: combo.label,
          phase: RunComboPhase.requestingModel,
          startedAt: now(),
        );
        _emitProgress(emit);

        try {
          final result = await _runCombo(
            combo,
            _currentRunId,
            _evaluatorConfig,
            _active,
            emit,
          );
          await runDao.persistTaskRun(result);
          _resultSlots[comboIndex] = result;
        } catch (e, st) {
          await _handleComboFailure(combo, e, st, emit);
        }

        _active.remove(comboIndex);
        _emitProgress(emit);
      }
    } finally {
      _runningWorkers--;
      _ensureWorkers(emit);

      if (_runningWorkers == 0 && _pendingQueue.isEmpty && _active.isEmpty) {
        if (_failed.isEmpty &&
            _resultSlots.whereType<TaskRunResult>().length == _combos.length) {
          await _tryAutoFinish(emit);
        } else if (!(_drainDone?.isCompleted ?? true)) {
          _drainDone!.complete();
        }
      }
    }
  }

  Future<void> _handleComboFailure(
    _Combo combo,
    Object error,
    StackTrace stackTrace,
    Emitter<RunState> emit,
  ) async {
    final snapshot = FailedComboSnapshot(
      index: combo.index,
      label: combo.label,
      providerId: combo.provider.id,
      modelId: combo.modelId,
      taskId: combo.task.id,
      errorMessage: error.toString(),
      stackTrace: stackTrace.toString(),
      failedAt: now(),
    );

    final synthetic = TaskRunResult(
      runId: _currentRunId,
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
          rationale: 'combo failed during run: $error',
          details: {'phase': 'run', 'error': '$error'},
        ),
      ],
      aggregateScore: 0.0,
      completedAt: now(),
      planId: combo.planId,
    );

    try {
      await runDao.persistTaskRun(synthetic);
      _resultSlots[combo.index] = synthetic;
      _failed[combo.index] = snapshot;
    } catch (persistError) {
      debugPrint('persist failed: $persistError');
      final persistSnapshot = FailedComboSnapshot(
        index: combo.index,
        label: combo.label,
        providerId: combo.provider.id,
        modelId: combo.modelId,
        taskId: combo.task.id,
        errorMessage: 'persist failed: $persistError',
        stackTrace: null,
        failedAt: now(),
      );
      _failed[combo.index] = persistSnapshot;
    }
  }

  Future<void> _tryAutoFinish(Emitter<RunState> emit) async {
    if (_currentRunId.isEmpty || emit.isDone) return;
    try {
      await runDao.finishRun(_currentRunId, now());
      final finalResults = List<TaskRunResult>.unmodifiable(
        _resultSlots.whereType<TaskRunResult>(),
      );
      if (!emit.isDone) {
        emit(RunCompleted(runId: _currentRunId, results: finalResults));
      }
      if (!(_drainDone?.isCompleted ?? true)) {
        _drainDone?.complete();
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(RunFailed('$e'));
      }
      if (!(_drainDone?.isCompleted ?? true)) {
        _drainDone?.completeError(e);
      }
    }
  }

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
    _resetScheduler();
    final runId = event.existingRunId ?? idGenerator();
    _currentRunId = runId;

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

    var existingCount = 0;
    if (event.existingRunId != null) {
      final existing = await runDao.taskRunsForRun(event.existingRunId!);
      existingCount = existing.length;
    }

    _maxConcurrency = event.maxConcurrency.clamp(1, 8);
    _providers = event.providers;
    _combos = combos;
    _resultSlots = List<TaskRunResult?>.filled(combos.length, null);
    _existingCount = existingCount;
    _evaluatorConfig = event.evaluatorConfig;

    _emitProgress(emit);

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
      _combos = combos;

      for (var i = 0; i < _combos.length; i++) {
        _pendingQueue.add(i);
      }

      _drainDone = Completer<void>();
      _ensureWorkers(emit);
      _emitProgress(emit);
      try {
        await _drainDone!.future;
      } catch (_) {
        // error already surfaced by _tryAutoFinish / _onFinishRun
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(RunFailed('$e'));
      }
    }
  }

  Future<void> _onRetry(RetryCombo event, Emitter<RunState> emit) async {
    if (state is! RunInProgress) return;
    if (event.runId != _currentRunId) return;
    if (event.failedIndex < 0 || event.failedIndex >= _combos.length) return;
    if (!_failed.containsKey(event.failedIndex)) return;
    if (_retrying.contains(event.failedIndex)) return;
    if (_pendingQueue.contains(event.failedIndex)) return;
    if (_active.containsKey(event.failedIndex)) return;

    _retrying.add(event.failedIndex);
    final combo = _combos[event.failedIndex];

    try {
      await runDao.deleteTaskRunByKey(
        runId: _currentRunId,
        providerId: combo.provider.id,
        modelId: combo.modelId,
        taskId: combo.task.id,
      );
    } catch (_) {
      _retrying.remove(event.failedIndex);
      if (!emit.isDone) {
        emit(
          RunFailed('Failed to delete prior row for retry of ${combo.label}'),
        );
      }
      return;
    }

    _failed.remove(event.failedIndex);
    _resultSlots[event.failedIndex] = null;
    _retrying.remove(event.failedIndex);
    _pendingQueue.add(event.failedIndex);
    _emitProgress(emit);

    _drainDone = Completer<void>();
    _ensureWorkers(emit);
    try {
      await _drainDone!.future;
    } catch (_) {
      // error already surfaced
    }
  }

  Future<void> _onFinishRun(FinishRun event, Emitter<RunState> emit) async {
    if (state is! RunInProgress) return;
    if (event.runId != _currentRunId) return;
    if (_pendingQueue.isNotEmpty) return;
    if (_active.isNotEmpty) return;
    if (_runningWorkers != 0) return;
    if (_failed.isEmpty) return;

    try {
      await runDao.finishRun(_currentRunId, now());
      final finalResults = List<TaskRunResult>.unmodifiable(
        _resultSlots.whereType<TaskRunResult>(),
      );
      if (!emit.isDone) {
        emit(RunCompleted(runId: _currentRunId, results: finalResults));
      }
      if (!(_drainDone?.isCompleted ?? true)) {
        _drainDone?.complete();
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(RunFailed('$e'));
      }
      if (!(_drainDone?.isCompleted ?? true)) {
        _drainDone?.completeError(e);
      }
    }
  }

  Future<TaskRunResult> _runCombo(
    _Combo combo,
    String runId,
    EvaluatorConfig evaluatorConfig,
    Map<int, RunProgressSnapshot> active,
    Emitter<RunState> emit,
  ) async {
    final task = combo.task;
    final provider = combo.provider;
    final modelId = combo.modelId;

    final prompt = buildPromptWithPlan(
      taskPrompt: task.prompt,
      planMarkdown: combo.planMarkdown,
    );

    ModelResponse response;

    void updateActive(int index, RunProgressSnapshot snapshot) {
      active[index] = snapshot;
    }

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
      _emitProgress(emit);

      await for (final event in provider.generateStream(
        prompt: prompt,
        model: modelId,
        timeout: const Duration(minutes: 10),
      )) {
        switch (event) {
          case ModelStreamReasoningDelta(:final text):
            reasoningPreview = _trimPreview(reasoningPreview + text);
            updateActive(
              combo.index,
              active[combo.index]!.copyWith(reasoningPreview: reasoningPreview),
            );
            _emitProgress(emit);
          case ModelStreamContentDelta(:final text):
            answerPreview = _trimPreview(answerPreview + text);
            rawBuf.write(text);
            updateActive(
              combo.index,
              active[combo.index]!.copyWith(answerPreview: answerPreview),
            );
            _emitProgress(emit);
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
            _emitProgress(emit);
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
      _emitProgress(emit);

      response = await provider.generate(
        prompt: prompt,
        model: modelId,
        timeout: const Duration(minutes: 10),
      );

      updateActive(
        combo.index,
        active[combo.index]!.copyWith(
          answerPreview: _trimPreview(response.rawText),
          promptTokens: response.promptTokens,
          completionTokens: response.completionTokens,
          phase: RunComboPhase.extractingCode,
        ),
      );
      _emitProgress(emit);
    }

    updateActive(
      combo.index,
      active[combo.index]!.copyWith(phase: RunComboPhase.extractingCode),
    );
    _emitProgress(emit);

    final extracted = extractDartCode(response.rawText) ?? response.rawText;
    final responseWithCode = _copyWithCode(response, extracted);

    updateActive(
      combo.index,
      active[combo.index]!.copyWith(phase: RunComboPhase.creatingWorkdir),
    );
    _emitProgress(emit);

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
    _emitProgress(emit);

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
      _emitProgress(emit);

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
    _emitProgress(emit);

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
