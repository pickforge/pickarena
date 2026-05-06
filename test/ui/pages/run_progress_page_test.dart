import 'dart:async';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/ui/pages/run_progress_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRunBloc extends Mock implements RunBloc {}

class _Provider implements ModelProvider {
  @override
  String get id => 'p';
  @override
  String get displayName => 'P';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => ['m'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => const ModelResponse(
    rawText: '',
    extractedCode: null,
    promptTokens: null,
    completionTokens: null,
    latency: Duration.zero,
  );
}

class _Task extends BenchmarkTask {
  @override
  String get id => 't';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'p';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/a.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      StartRun(
        tasks: [_Task()],
        providers: [_Provider()],
        modelsByProvider: const {
          'p': ['m'],
        },
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );
  });

  final now = DateTime(2025, 1, 1, 12, 0, 0);

  Widget build(RunBloc bloc) => MaterialApp(
    home: BlocProvider<RunBloc>.value(
      value: bloc,
      child: const RunProgressPage(),
    ),
  );

  MockRunBloc createBloc(RunState state) {
    final bloc = MockRunBloc();
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => StreamController<RunState>().stream);
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
    return bloc;
  }

  testWidgets('active snapshot renders label and phase', (tester) async {
    final bloc = createBloc(
      RunInProgress(
        runId: 'r',
        completed: 0,
        total: 1,
        results: const [],
        active: [
          RunProgressSnapshot(
            index: 0,
            label: 'Fake / m1 on stub',
            phase: RunComboPhase.streamingResponse,
            startedAt: now,
          ),
        ],
      ),
    );

    await tester.pumpWidget(build(bloc));
    await tester.pump();

    expect(find.text('Fake / m1 on stub'), findsOneWidget);
    expect(find.text('Streaming response...'), findsOneWidget);
  });

  testWidgets('Thinking and Answer panels show streamed text', (tester) async {
    final bloc = createBloc(
      RunInProgress(
        runId: 'r',
        completed: 0,
        total: 1,
        results: const [],
        active: [
          RunProgressSnapshot(
            index: 0,
            label: 'X / m on t',
            phase: RunComboPhase.streamingResponse,
            startedAt: now,
            reasoningPreview: 'think step 1',
            answerPreview: 'code here',
          ),
        ],
      ),
    );

    await tester.pumpWidget(build(bloc));
    await tester.pump();

    expect(find.text('Thinking'), findsOneWidget);

    await tester.tap(find.text('Thinking'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('think step 1'), findsOneWidget);

    await tester.tap(find.text('Answer'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('code here'), findsOneWidget);
  });

  testWidgets('completed results render while in progress', (tester) async {
    final bloc = createBloc(
      RunInProgress(
        runId: 'r',
        completed: 1,
        total: 2,
        results: [
          TaskRunResult(
            runId: 'r',
            providerId: 'p',
            modelId: 'm',
            taskId: 't',
            response: const ModelResponse(
              rawText: 'ok',
              extractedCode: null,
              promptTokens: 1,
              completionTokens: 2,
              latency: Duration(milliseconds: 10),
            ),
            evaluations: const [],
            aggregateScore: 0.9,
            completedAt: now,
          ),
        ],
        active: [
          RunProgressSnapshot(
            index: 1,
            label: 'P2 / m2 on t2',
            phase: RunComboPhase.evaluating,
            startedAt: now,
          ),
        ],
      ),
    );

    await tester.pumpWidget(build(bloc));
    await tester.pump();

    expect(find.text('1 / 2 completed'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('p / m'), findsOneWidget);
    expect(find.text('P2 / m2 on t2'), findsOneWidget);
  });

  testWidgets('failed state can retry failed task', (tester) async {
    final retry = StartRun(
      tasks: [_Task()],
      providers: [_Provider()],
      modelsByProvider: const {
        'p': ['m'],
      },
      evaluatorConfig: const EvaluatorConfig(),
      existingRunId: 'r',
    );
    final bloc = createBloc(RunFailed('timeout', retry: retry));

    await tester.pumpWidget(build(bloc));
    await tester.pump();

    expect(find.textContaining('Failed: timeout'), findsOneWidget);
    await tester.tap(find.text('Retry failed task'));
    await tester.pump();

    verify(() => bloc.add(retry)).called(1);
  });
}
