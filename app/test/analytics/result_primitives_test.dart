import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:flutter_test/flutter_test.dart';

EvaluationResult _ev(String id, bool passed) => EvaluationResult(
  evaluatorId: id,
  passed: passed,
  score: passed ? 1.0 : 0.0,
);

void main() {
  test('hidden verifier determines primary pass when present', () {
    final primitives = determineResultPrimitives(
      evaluations: [_ev('compile', true), _ev('hidden_test', false)],
      aggregateScore: 1.0,
      response: const ModelResponse(
        rawText: 'code',
        extractedCode: 'code',
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
    );

    expect(primitives.primaryPass, isFalse);
    expect(primitives.failureTag, 'hidden_verifier_failed');
  });

  test('correctness evaluators determine pass before aggregate fallback', () {
    final primitives = determineResultPrimitives(
      evaluations: [_ev('compile', true), _ev('test', false)],
      aggregateScore: 0.9,
    );

    expect(primitives.primaryPass, isFalse);
    expect(primitives.failureTag, 'public_tests_failed');
  });

  test('aggregate score is fallback when correctness is absent', () {
    final primitives = determineResultPrimitives(
      evaluations: [_ev('llm_judge', false)],
      aggregateScore: 0.6,
    );

    expect(primitives.primaryPass, isTrue);
    expect(primitives.failureTag, 'pass');
  });

  test('failure tag precedence is stable', () {
    final primitives = determineResultPrimitives(
      evaluations: [
        _ev('hidden_test', false),
        _ev('compile', false),
        const EvaluationResult(
          evaluatorId: 'combo_failure',
          passed: false,
          score: 0,
          rationale: 'request timeout',
          details: {'error': 'TimeoutException'},
        ),
      ],
      aggregateScore: 0,
    );

    expect(primitives.failureTag, 'harness_timeout');
  });

  test('harness errors fail primary pass even when hidden verifier passes', () {
    final primitives = determineResultPrimitives(
      evaluations: [
        _ev('hidden_test', true),
        const EvaluationResult(
          evaluatorId: 'agent_harness',
          passed: false,
          score: 0,
          rationale: 'agent harness failed',
          details: {'error': 'exit code 1'},
        ),
      ],
      aggregateScore: 0.5,
    );

    expect(primitives.primaryPass, isFalse);
    expect(primitives.failureTag, 'harness_error');
  });

  test(
    'empty output is classified as invalid output when failing fallback',
    () {
      final primitives = determineResultPrimitives(
        evaluations: const [],
        aggregateScore: 0,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
      );

      expect(primitives.primaryPass, isFalse);
      expect(primitives.failureTag, 'invalid_output');
    },
  );

  test('secondary LLM judge failure does not override correctness pass', () {
    final primitives = determineResultPrimitives(
      evaluations: const [
        EvaluationResult(evaluatorId: 'compile', passed: true, score: 1),
        EvaluationResult(
          evaluatorId: 'llm_judge',
          passed: false,
          score: 0,
          details: {'error': 'judge unavailable'},
        ),
      ],
      aggregateScore: 1,
    );

    expect(primitives.primaryPass, isTrue);
    expect(primitives.failureTag, 'pass');
  });

  test('environment errors have stable taxonomy before harness errors', () {
    final primitives = determineResultPrimitives(
      evaluations: const [
        EvaluationResult(
          evaluatorId: 'environment',
          passed: false,
          score: 0,
          details: {'code': 'environment_error', 'error': 'disk full'},
        ),
        EvaluationResult(
          evaluatorId: 'agent_harness',
          passed: false,
          score: 0,
          details: {'error': 'exit code 1'},
        ),
      ],
      aggregateScore: 0,
    );

    expect(primitives.primaryPass, isFalse);
    expect(primitives.failureTag, 'environment_error');
  });

  test('non-empty output without extracted patch is no_patch', () {
    final primitives = determineResultPrimitives(
      evaluations: const [],
      aggregateScore: 0,
      response: const ModelResponse(
        rawText: 'I cannot modify the code.',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
    );

    expect(primitives.primaryPass, isFalse);
    expect(primitives.failureTag, 'no_patch');
  });
}
