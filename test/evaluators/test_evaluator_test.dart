import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
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

Future<Directory> _scaffold({
  required String libContents,
  required String testContents,
}) async {
  final root = await Directory.systemTemp.createTemp('dart_arena_test_eval_');
  final dir = Directory(p.join(root.path, 'pkg'))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync(libContents);
  Directory(p.join(dir.path, 'test')).createSync();
  File(
    p.join(dir.path, 'test', 'tmp_test.dart'),
  ).writeAsStringSync(testContents);
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
  test('all-pass scores 1.0', () async {
    final dir = await _scaffold(
      libContents: 'int answer() => 42;\n',
      testContents: '''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('a', () { expect(answer(), 42); });
  test('b', () { expect(answer(), 42); });
}
''',
    );
    final r = await TestEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isTrue);
    expect(r.score, 1.0);
    expect(r.details['total'], 2);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'two of three passing scores ~0.667',
    () async {
      final dir = await _scaffold(
        libContents: 'int answer() => 41;\n',
        testContents: '''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('a', () { expect(answer(), 41); });
  test('b', () { expect(answer(), 42); });
  test('c', () { expect(answer(), 41); });
}
''',
      );
      final r = await TestEvaluator().evaluate(_ctx(dir));
      expect(r.passed, isFalse);
      expect(r.score, closeTo(2.0 / 3.0, 1e-6));
      expect(r.details['total'], 3);
      expect(r.details['failed'], 1);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
