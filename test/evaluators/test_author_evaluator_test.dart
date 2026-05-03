import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_author_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Task extends BenchmarkTask {
  @override
  String get id => 'test.fixture';

  @override
  Category get category => Category.widgetTesting;

  @override
  String get prompt => '';

  @override
  Map<String, String> get fixtures => const {};

  @override
  String? get judgeRubric => null;

  @override
  String get generatedCodePath => 'test/calc_test.dart';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('test_author_eval_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('scores 1.0 when generated tests kill the mutant', () async {
    await _writeFixture(root, '''
import 'package:test/test.dart';
import 'package:test_author_fixture/calc.dart';

void main() {
  test('isEnabled rejects blank text', () {
    expect(isEnabled('x'), isTrue);
    expect(isEnabled('   '), isFalse);
  });
}
''');

    final result = await _evaluate(root);

    expect(result.passed, isTrue);
    expect(result.score, 1.0);
  });

  test('scores 0.0 when generated tests do not kill the mutant', () async {
    await _writeFixture(root, '''
import 'package:test/test.dart';

void main() {
  test('trivial', () {
    expect(true, isTrue);
  });
}
''');

    final result = await _evaluate(root);

    expect(result.passed, isFalse);
    expect(result.score, 0.0);
    expect(result.details['survived'], ['always_enabled']);
  });
}

Future<void> _writeFixture(Directory dir, String testBody) async {
  await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: test_author_fixture
publish_to: none
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
  await Directory(p.join(dir.path, 'lib')).create(recursive: true);
  await Directory(p.join(dir.path, 'test')).create(recursive: true);
  await File(p.join(dir.path, 'lib', 'calc.dart')).writeAsString('''
bool isEnabled(String text) => text.trim().isNotEmpty;
''');
  await File(p.join(dir.path, 'test', 'calc_test.dart')).writeAsString(testBody);

  final pubGet = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: dir.path,
  );
  expect(pubGet.exitCode, 0, reason: pubGet.stderr.toString());
}

Future<EvaluationResult> _evaluate(Directory dir) {
  return TestAuthorEvaluator(
    testPath: 'test/calc_test.dart',
    mutants: const [
      TestMutant(
        name: 'always_enabled',
        sourcePath: 'lib/calc.dart',
        find: 'text.trim().isNotEmpty',
        replace: 'true',
      ),
    ],
  ).evaluate(EvaluationContext(
    workDir: dir,
    task: _Task(),
    response: const ModelResponse(
      rawText: '',
      extractedCode: '',
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
  ));
}
