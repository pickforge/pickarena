import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _DummyTask extends BenchmarkTask {
  @override
  String get id => 'dummy';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<Directory> _scaffold(String fileContents) async {
  final root = await Directory.systemTemp.createTemp('dart_arena_analyze_');
  final dir = Directory(p.join(root.path, 'pkg'))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync(fileContents);
  await WorkdirManager(root: root).prepare(dir);
  return dir;
}

EvaluationContext _ctx(Directory dir) => EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _DummyTask(),
    );

void main() {
  test('clean code scores 1.0 and passes', () async {
    final dir = await _scaffold('int answer() => 42;\n');
    final r = await AnalyzeEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isTrue);
    expect(r.score, 1.0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('code with errors scores 0.0 and fails', () async {
    final dir = await _scaffold('int answer( => 42;');
    final r = await AnalyzeEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isFalse);
    expect(r.score, 0.0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('warning-only code scores between 0 and 1', () async {
    final dir = await _scaffold('''
int answer() {
  final x = 1;
  return 42;
}
''');
    final r = await AnalyzeEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isTrue);
    expect(r.score, lessThan(1.0));
    expect(r.score, greaterThan(0.0));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
