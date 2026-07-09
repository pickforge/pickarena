import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:test/test.dart';

void main() {
  test('compile failure blocks runtime evaluators but not analyze', () {
    const previous = [
      EvaluationResult(evaluatorId: 'compile', passed: false, score: 0.0),
    ];

    expect(
      blockedEvaluationFor(evaluatorId: 'analyze', previousResults: previous),
      isNull,
    );

    final testBlocked = blockedEvaluationFor(
      evaluatorId: 'test',
      previousResults: previous,
    );
    expect(testBlocked, isNotNull);
    expect(testBlocked!.passed, isFalse);
    expect(testBlocked.score, 0.0);
    expect(testBlocked.rationale, 'blocked by compile');
    expect(testBlocked.details[blockedDetailKey], isTrue);
    expect(testBlocked.details[blockedByDetailKey], 'compile');
    expect(testBlocked.details[blockedByRationaleDetailKey], isNull);

    final hiddenBlocked = blockedEvaluationFor(
      evaluatorId: 'task_hidden',
      previousResults: previous,
    );
    expect(hiddenBlocked, isNotNull);
    expect(hiddenBlocked!.details[blockedByDetailKey], 'compile');
  });

  test('agent harness failure blocks all objective task evaluators', () {
    const previous = [
      EvaluationResult(evaluatorId: 'agent_harness', passed: false, score: 0.0),
    ];

    for (final evaluatorId in ['compile', 'analyze', 'test', 'task_hidden']) {
      final blocked = blockedEvaluationFor(
        evaluatorId: evaluatorId,
        previousResults: previous,
      );
      expect(blocked, isNotNull);
      expect(blocked!.details[blockedByDetailKey], 'agent_harness');
    }
  });

  test(
    'environment failure blocks all downstream evaluators with rationale',
    () {
      const previous = [
        EvaluationResult(
          evaluatorId: 'environment',
          passed: false,
          score: 0.0,
          rationale: 'prepare failed',
          details: {'code': 'environment_error'},
        ),
      ];

      for (final evaluatorId in ['compile', 'analyze', 'test', 'llm_judge']) {
        final blocked = blockedEvaluationFor(
          evaluatorId: evaluatorId,
          previousResults: previous,
          blockAllDownstream: true,
        );
        expect(blocked, isNotNull);
        expect(blocked!.details[blockedByDetailKey], 'environment');
        expect(blocked.details[blockedByRationaleDetailKey], 'prepare failed');
      }
    },
  );

  test('secondary evaluators are not blocked by objective failures', () {
    const previous = [
      EvaluationResult(evaluatorId: 'compile', passed: false, score: 0.0),
    ];

    expect(
      blockedEvaluationFor(evaluatorId: 'llm_judge', previousResults: previous),
      isNull,
    );
  });
}
