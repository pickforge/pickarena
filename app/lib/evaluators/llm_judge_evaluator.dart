import 'dart:convert';

import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_classification.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';

class LlmJudgeEvaluator implements Evaluator {
  LlmJudgeEvaluator({required this.judge, required this.judgeModel});

  final ModelProvider judge;
  final String judgeModel;

  @override
  String get id => 'llm_judge';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final blockingFailures = ctx.previousResults
        .where(
          (result) => result.evaluatorId == 'agent_harness' && !result.passed,
        )
        .map((result) => result.evaluatorId)
        .toList(growable: false);
    if (blockingFailures.isNotEmpty) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'ignored due to blocking evaluator failure',
        details: {
          'ignored': true,
          'skipped': true,
          'reason': 'blocking_failure',
          'failed_evaluator_ids': blockingFailures,
        },
      );
    }

    final objectiveFailures = ctx.previousResults
        .where(isObjectiveFailure)
        .map((result) => result.evaluatorId)
        .toList(growable: false);
    if (objectiveFailures.isNotEmpty) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'ignored due to objective evaluator failure',
        details: {
          'ignored': true,
          'skipped': true,
          'reason': 'objective_failure',
          'failed_evaluator_ids': objectiveFailures,
        },
      );
    }

    final rubric = ctx.task.judgeRubric;
    if (rubric == null) {
      return EvaluationResult(
        evaluatorId: id,
        passed: true,
        score: 1.0,
        rationale: 'no rubric',
        details: const {'skipped': true, 'reason': 'no_rubric'},
      );
    }

    final submission = ctx.response.extractedCode ?? ctx.response.rawText;
    final targetContext = buildPromptSafeTargetContext(
      targetPath: ctx.task.generatedCodePath,
      fixtures: ctx.task.fixtures,
    );
    final publicTests = buildPublicTestFixtureContext(
      fixtures: ctx.task.fixtures,
    );
    final priorSummary = _priorObjectiveSummary(ctx.previousResults);
    final prompt =
        '''
You are a strict code reviewer for Dart/Flutter.

Penalize public API breakage, compile failures, analysis failures, and public or hidden test failures. Do not let stylistic strengths outweigh objective correctness failures.

TASK PROMPT:
${ctx.task.prompt}

TARGET API/SKELETON:
${targetContext ?? 'Not available.'}

PUBLIC TEST FIXTURE SNIPPETS:
${publicTests ?? 'Not available.'}

PRIOR OBJECTIVE EVALUATION SUMMARY:
$priorSummary

RUBRIC:
$rubric

SUBMISSION:
```dart
$submission
```

Reply with ONLY a fenced ```json block of the form:
{"score": <number 0.0-1.0>, "rationale": "<short reasoning>"}
''';

    final response = await judge.generate(
      prompt: prompt,
      model: judgeModel,
      timeout: const Duration(minutes: 10),
    );
    final raw = response.rawText;

    final parsed = _parse(raw);
    final score = parsed.score.clamp(0.0, 1.0);
    final judgeCost = const CostEstimator().estimateDetailed(
      providerId: judge.id,
      modelId: judgeModel,
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
    );

    return EvaluationResult(
      evaluatorId: id,
      passed: score >= 0.5,
      score: score,
      rationale: parsed.rationale,
      details: {
        'raw_judge_response': raw.length > 4000 ? raw.substring(0, 4000) : raw,
        'judge_model': judgeModel,
        'judge_provider_id': judge.id,
        'parse_strategy': parsed.strategy,
        'judge_overhead': {
          'provider_id': judge.id,
          'model_id': judgeModel,
          'prompt_tokens': response.promptTokens,
          'completion_tokens': response.completionTokens,
          'estimated_cost_micros': judgeCost.micros,
          'pricing_status': judgeCost.pricingStatus,
          'pricing_registry_version': defaultPricingRegistryVersion,
          'pricing_currency': defaultPricingRegistryCurrency,
        },
      },
    );
  }

  String _priorObjectiveSummary(List<EvaluationResult> previousResults) {
    final objectiveResults = previousResults
        .where((result) => isObjectiveEvaluatorId(result.evaluatorId))
        .toList(growable: false);
    if (objectiveResults.isEmpty) {
      return 'No prior objective evaluator results.';
    }

    return objectiveResults
        .map(
          (result) =>
              '- ${result.evaluatorId}: '
              '${result.passed ? 'passed' : 'failed'}, '
              'score=${result.score.toStringAsFixed(2)}'
              '${result.rationale == null ? '' : ', ${result.rationale}'}',
        )
        .join('\n');
  }

  _ParsedJudgeReply _parse(String raw) {
    final block = extractJsonBlock(raw);
    if (block != null) {
      try {
        final m = jsonDecode(block) as Map<String, dynamic>;
        final s = m['score'];
        final r = m['rationale'];
        if (s is num) {
          return _ParsedJudgeReply(
            score: s.toDouble(),
            rationale: r is String ? r : null,
            strategy: 'json',
          );
        }
      } on FormatException {
        // fall through to regex
      }
    }

    final scoreRe = RegExp(
      r'score[\s:]+([0-9]*\.?[0-9]+)',
      caseSensitive: false,
    );
    final m = scoreRe.firstMatch(raw);
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      if (v != null) {
        final r = raw.length > 500 ? raw.substring(0, 500) : raw;
        return _ParsedJudgeReply(
          score: v > 1.0 ? v / 100.0 : v,
          rationale: r,
          strategy: 'regex',
        );
      }
    }

    return const _ParsedJudgeReply(
      score: 0.0,
      rationale: 'unparseable judge reply',
      strategy: 'fallback',
    );
  }
}

class _ParsedJudgeReply {
  const _ParsedJudgeReply({
    required this.score,
    required this.rationale,
    required this.strategy,
  });

  final double score;
  final String? rationale;
  final String strategy;
}
