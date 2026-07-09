import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:test/test.dart';

import '../support/official_tasks.dart';

void main() {
  test(
    'file-backed prompt context exposes public API without implementation',
    () async {
      final task = await loadOfficialFlutterTask('state.selection_controller');
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
      expect(prompt, contains('class SelectionController'));
      expect(prompt, contains('List<String> get selectedIds'));
      expect(prompt, contains('void toggle(String id)'));
      expect(prompt, contains('void clear()'));
      expect(prompt, isNot(contains('..clear()')));
    },
  );

  test('missing behavior compile failure cannot exceed compile cap', () {
    const knownMissingBehaviorFailure = [
      EvaluationResult(
        evaluatorId: 'compile',
        passed: false,
        score: 0.0,
        rationale: 'public API contract required by tests',
      ),
      EvaluationResult(evaluatorId: 'analyze', passed: false, score: 0.0),
      EvaluationResult(evaluatorId: 'test', passed: false, score: 0.0),
      EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
      EvaluationResult(evaluatorId: 'diff_size', passed: true, score: 1.0),
    ];

    expect(
      aggregate(knownMissingBehaviorFailure, defaultEvaluatorWeights),
      lessThanOrEqualTo(0.20),
    );
  });
}
