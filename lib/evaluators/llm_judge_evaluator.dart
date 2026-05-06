import 'dart:convert';

import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';

class LlmJudgeEvaluator implements Evaluator {
  LlmJudgeEvaluator({required this.judge, required this.judgeModel});

  final ModelProvider judge;
  final String judgeModel;

  @override
  String get id => 'llm_judge';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final rubric = ctx.task.judgeRubric;
    if (rubric == null) {
      return EvaluationResult(
        evaluatorId: id,
        passed: true,
        score: 1.0,
        rationale: 'no rubric',
        details: const {'skipped': true},
      );
    }

    final submission = ctx.response.extractedCode ?? ctx.response.rawText;
    final prompt =
        '''
You are a strict code reviewer for Dart/Flutter.

TASK PROMPT:
${ctx.task.prompt}

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
      timeout: const Duration(seconds: 60),
    );
    final raw = response.rawText;

    final parsed = _parse(raw);
    final score = parsed.score.clamp(0.0, 1.0);

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
      },
    );
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
