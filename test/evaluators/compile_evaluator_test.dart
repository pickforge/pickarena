import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
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
  List<Evaluator> get evaluators => const [];
  @override
  String? get judgeRubric => null;
}

void main() {
  test('passes for clean Dart code', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_eval_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer() => 42;\n');
    Directory(p.join(dir.path, 'test')).createSync();
    File(p.join(dir.path, 'test', 'tmp_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('answer', () {
    expect(answer(), 42);
  });
}
''');

    final result = await CompileEvaluator().evaluate(
      EvaluationContext(
        workDir: dir,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        task: _DummyTask(),
      ),
    );

    expect(result.passed, isTrue);
    expect(result.score, 1.0);
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('fails for code with syntax errors', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_eval_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer( => 42;');

    final result = await CompileEvaluator().evaluate(
      EvaluationContext(
        workDir: dir,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        task: _DummyTask(),
      ),
    );

    expect(result.passed, isFalse);
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('fails when tests fail', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_eval_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer() => 41;\n');
    Directory(p.join(dir.path, 'test')).createSync();
    File(p.join(dir.path, 'test', 'tmp_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('answer', () {
    expect(answer(), 42);
  });
}
''');

    final result = await CompileEvaluator().evaluate(
      EvaluationContext(
        workDir: dir,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        task: _DummyTask(),
      ),
    );

    expect(result.passed, isFalse);
    expect(result.rationale, 'tests failed');
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
