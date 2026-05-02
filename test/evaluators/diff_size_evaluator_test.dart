import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _original = '''
class A {
  int x() => 1;
  int y() => 2;
  int z() => 3;
}
''';

class _Task extends BenchmarkTask {
  _Task(this._fixtures);
  final Map<String, String> _fixtures;

  @override
  String get id => 'task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => _fixtures;
  @override
  String get generatedCodePath => 'lib/a.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<EvaluationContext> _ctxWith(String workdirContents) async {
  final dir = await Directory.systemTemp.createTemp('dart_arena_diff_');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'a.dart')).writeAsStringSync(workdirContents);
  return EvaluationContext(
    workDir: dir,
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    task: _Task({'lib/a.dart': _original}),
  );
}

void main() {
  test('identical contents score 1.0', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(await _ctxWith(_original));
    expect(r.score, closeTo(1.0, 1e-9));
    expect(r.passed, isTrue);
  });

  test('small diff produces score between 0 and 1', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified = _original.replaceFirst('=> 1;', '=> 10;');
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(1.0));
    expect(r.score, greaterThan(0.5));
  });

  test('large diff drives score toward 0', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified =
        List.generate(40, (i) => '// new line $i').join('\n') + '\n';
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(math.exp(-1.0)));
    expect(r.passed, isFalse);
  });

  test('missing splice file -> score 0', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_diff_miss_');
    final ctx = EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _Task({'lib/a.dart': _original}),
    );
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(ctx);
    expect(r.score, 0.0);
    expect(r.passed, isFalse);
    expect(r.rationale, contains('missing'));
  });
}
