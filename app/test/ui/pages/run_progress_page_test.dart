import 'dart:async';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(const RetryCombo(runId: '', failedIndex: 0));
    registerFallbackValue(const FinishRun(''));
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

  testWidgets('failed state shows error and back button', (tester) async {
    final bloc = createBloc(const RunFailed('timeout'));

    await tester.pumpWidget(build(bloc));
    await tester.pump();

    expect(find.textContaining('timeout'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });
}
