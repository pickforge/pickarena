import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:test/test.dart';

class _ScriptedJudge with Disposable implements ModelProvider {
  _ScriptedJudge(
    this._reply, {
    this.providerId = 'fake_judge',
    this.promptTokens,
    this.completionTokens,
  });
  final String _reply;
  final String providerId;
  final int? promptTokens;
  final int? completionTokens;
  var generateCalls = 0;
  String? lastPrompt;

  @override
  String get id => providerId;
  @override
  String get displayName => 'Fake Judge';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => [const ModelInfo(id: 'j1')];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    generateCalls++;
    lastPrompt = prompt;
    return ModelResponse(
      rawText: _reply,
      extractedCode: null,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      latency: const Duration(milliseconds: 1),
    );
  }
}

class _Task extends BenchmarkTask {
  _Task({this.rubric, this.fixtureMap = const {}});
  final String? rubric;
  final Map<String, String> fixtureMap;

  @override
  String get id => 'task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'fix it';
  @override
  Map<String, String> get fixtures => fixtureMap;
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => rubric;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

EvaluationContext _ctx(
  BenchmarkTask task, {
  List<EvaluationResult> previousResults = const [],
}) => EvaluationContext(
  workDir: Directory.systemTemp,
  response: const ModelResponse(
    rawText: 'submission text',
    extractedCode: 'int x = 0;',
    promptTokens: null,
    completionTokens: null,
    latency: Duration.zero,
  ),
  task: task,
  previousResults: previousResults,
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
      judge: _ScriptedJudge(
        reply,
        providerId: 'openai',
        promptTokens: 100,
        completionTokens: 20,
      ),
      judgeModel: 'gpt-5.3-codex',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'be strict')));
    expect(r.score, closeTo(0.85, 1e-9));
    expect(r.passed, isTrue);
    expect(r.rationale, contains('good fix'));
    expect(r.details['judge_provider_id'], 'openai');
    expect(r.details['judge_model'], 'gpt-5.3-codex');
    expect(r.details['judge_overhead'], {
      'provider_id': 'openai',
      'model_id': 'gpt-5.3-codex',
      'prompt_tokens': 100,
      'completion_tokens': 20,
      'estimated_cost_micros': 325,
      'pricing_status': 'exact',
      'pricing_registry_version': '2026-05-31',
      'pricing_currency': 'USD',
    });
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

  test(
    'skips without calling judge when prior objective failure exists',
    () async {
      final judge = _ScriptedJudge('irrelevant');
      final ev = LlmJudgeEvaluator(judge: judge, judgeModel: 'j1');

      final r = await ev.evaluate(
        _ctx(
          _Task(rubric: 'r'),
          previousResults: const [
            EvaluationResult(evaluatorId: 'compile', passed: false, score: 0.0),
          ],
        ),
      );

      expect(judge.generateCalls, 0);
      expect(r.passed, isFalse);
      expect(r.score, 0.0);
      expect(r.details['ignored'], isTrue);
      expect(r.details['reason'], 'objective_failure');
      expect(r.details['failed_evaluator_ids'], contains('compile'));
    },
  );

  test('custom hidden verifier failure gates the judge', () async {
    final judge = _ScriptedJudge('irrelevant');
    final ev = LlmJudgeEvaluator(judge: judge, judgeModel: 'j1');

    final r = await ev.evaluate(
      _ctx(
        _Task(rubric: 'r'),
        previousResults: const [
          EvaluationResult(
            evaluatorId: 'reference_hidden',
            passed: false,
            score: 0.0,
          ),
        ],
      ),
    );

    expect(judge.generateCalls, 0);
    expect(r.details['failed_evaluator_ids'], contains('reference_hidden'));
  });

  test('agent harness failure gates the judge', () async {
    final judge = _ScriptedJudge('irrelevant');
    final ev = LlmJudgeEvaluator(judge: judge, judgeModel: 'j1');

    final r = await ev.evaluate(
      _ctx(
        _Task(rubric: 'r'),
        previousResults: const [
          EvaluationResult(
            evaluatorId: 'agent_harness',
            passed: false,
            score: 0.0,
          ),
        ],
      ),
    );

    expect(judge.generateCalls, 0);
    expect(r.passed, isFalse);
    expect(r.score, 0.0);
    expect(r.details['ignored'], isTrue);
    expect(r.details['reason'], 'blocking_failure');
    expect(r.details['failed_evaluator_ids'], contains('agent_harness'));
  });

  test(
    'judge prompt includes safe target, public tests, and prior summary',
    () async {
      const reply = '```json\n{"score": 0.75, "rationale": "mostly ok"}\n```';
      final judge = _ScriptedJudge(reply);
      final ev = LlmJudgeEvaluator(judge: judge, judgeModel: 'j1');

      await ev.evaluate(
        _ctx(
          _Task(
            rubric: 'be strict',
            fixtureMap: const {
              'lib/tmp.dart': '''
class Api {
  const Api();
  int value() => 1;
}
''',
              'test/tmp_test.dart': 'void main() => expect(Api().value(), 1);',
              'test/_hidden/tmp_hidden_test.dart': 'hidden secret',
            },
          ),
          previousResults: const [
            EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
          ],
        ),
      );

      final prompt = judge.lastPrompt!;
      expect(prompt, contains('TARGET API/SKELETON'));
      expect(prompt, contains('const Api();'));
      expect(prompt, contains('implementation omitted'));
      expect(prompt, isNot(contains('=> 1')));
      expect(prompt, contains('PUBLIC TEST FIXTURE SNIPPETS'));
      expect(prompt, contains('test/tmp_test.dart'));
      expect(prompt, contains('expect(Api().value(), 1)'));
      expect(prompt, isNot(contains('hidden secret')));
      expect(prompt, contains('- compile: passed, score=1.00'));
    },
  );
}
