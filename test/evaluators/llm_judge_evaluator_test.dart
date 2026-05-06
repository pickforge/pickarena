import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedJudge implements ModelProvider {
  _ScriptedJudge(this._reply);
  final String _reply;

  @override
  String get id => 'fake_judge';
  @override
  String get displayName => 'Fake Judge';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<String>> listModels() async => ['j1'];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => ModelResponse(
    rawText: _reply,
    extractedCode: null,
    promptTokens: null,
    completionTokens: null,
    latency: const Duration(milliseconds: 1),
  );
}

class _Task extends BenchmarkTask {
  _Task({this.rubric});
  final String? rubric;

  @override
  String get id => 'task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'fix it';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => rubric;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

EvaluationContext _ctx(BenchmarkTask task) => EvaluationContext(
  workDir: Directory.systemTemp,
  response: const ModelResponse(
    rawText: 'submission text',
    extractedCode: 'int x = 0;',
    promptTokens: null,
    completionTokens: null,
    latency: Duration.zero,
  ),
  task: task,
);

void main() {
  test('skips with score 1.0 when task has no rubric', () async {
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge('irrelevant'),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task()));
    expect(r.passed, isTrue);
    expect(r.score, 1.0);
    expect(r.rationale, 'no rubric');
  });

  test('parses fenced JSON happy path', () async {
    const reply = '''
```json
{"score": 0.85, "rationale": "good fix"}
```
''';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'be strict')));
    expect(r.score, closeTo(0.85, 1e-9));
    expect(r.passed, isTrue);
    expect(r.rationale, contains('good fix'));
  });

  test('regex fallback recovers a score from unfenced text', () async {
    const reply = 'I think the score: 0.4 because ...';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'be strict')));
    expect(r.score, closeTo(0.4, 1e-9));
    expect(r.passed, isFalse);
  });

  test('clamps out-of-range score to [0,1]', () async {
    const reply = '```json\n{"score": 1.7, "rationale": "x"}\n```\n';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'r')));
    expect(r.score, 1.0);
  });

  test('returns score 0 when no parseable signal', () async {
    const reply = 'I refuse to judge.';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'r')));
    expect(r.score, 0.0);
    expect(r.passed, isFalse);
  });
}
