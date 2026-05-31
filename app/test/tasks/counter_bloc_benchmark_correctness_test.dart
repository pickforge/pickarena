import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/tasks/state_management/counter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'counter bloc prompt exposes const event constructor contract',
    () async {
      final task = CounterBlocTask();
      await task.ensureLoaded();

      final targetContext = buildPromptSafeTargetContext(
        targetPath: task.generatedCodePath,
        fixtures: task.fixtures,
      );
      final prompt = buildPromptWithPlan(
        taskPrompt: task.prompt,
        targetContext: targetContext,
        planMarkdown: null,
      );

      expect(prompt, contains('CURRENT TARGET FILE API/SKELETON'));
      expect(prompt, contains('const Increment();'));
      expect(prompt, contains('const Decrement();'));
      expect(prompt, contains('const Reset();'));
      expect(prompt, isNot(contains('emit(')));
    },
  );

  test('missing const compile failure cannot exceed compile cap', () {
    const knownMissingConstFailure = [
      EvaluationResult(
        evaluatorId: 'compile',
        passed: false,
        score: 0.0,
        rationale: 'const constructor required by tests',
      ),
      EvaluationResult(evaluatorId: 'analyze', passed: false, score: 0.0),
      EvaluationResult(evaluatorId: 'test', passed: false, score: 0.0),
      EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
      EvaluationResult(evaluatorId: 'diff_size', passed: true, score: 1.0),
    ];

    expect(
      aggregate(knownMissingConstFailure, defaultEvaluatorWeights),
      lessThanOrEqualTo(0.20),
    );
  });
}
