import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
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

Future<Directory> _scaffold(
  Directory root, {
  String lib = 'int answer() => 42;',
}) async {
  final dir = Directory(p.join(root.path, 'pkg'))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync('$lib\n');
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
  test(
    'injects hidden tests for evaluation and removes them afterward',
    () async {
      final root = await Directory.systemTemp.createTemp('hidden_eval_pass_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = await _scaffold(root);
      final hiddenPath = p.join(
        dir.path,
        'test',
        '_hidden',
        'answer_hidden_test.dart',
      );
      expect(File(hiddenPath).existsSync(), isFalse);

      final result = await HiddenTestEvaluator(
        const VerifierFixture(
          files: {
            'test/_hidden/answer_hidden_test.dart': '''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('answer is correct', () => expect(answer(), 42));
}
''',
          },
          testPath: 'test/_hidden/answer_hidden_test.dart',
        ),
      ).evaluate(_ctx(dir));

      expect(result.evaluatorId, 'hidden_test');
      expect(result.passed, isTrue);
      expect(result.details['total'], 1);
      expect(result.details['injected_files'], [
        'test/_hidden/answer_hidden_test.dart',
      ]);
      expect(File(hiddenPath).existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'does not persist hidden verifier source in failure details',
    () async {
      final root = await Directory.systemTemp.createTemp('hidden_eval_fail_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = await _scaffold(root);

      final result = await HiddenTestEvaluator(
        const VerifierFixture(
          files: {
            'test/_hidden/answer_hidden_test.dart': '''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('secret hidden behavior name', () {
    const token = 'DO_NOT_LEAK_HIDDEN_SOURCE';
    expect(answer(), 0, reason: token);
  });
}
''',
          },
          testPath: 'test/_hidden/answer_hidden_test.dart',
        ),
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      final detailsJson = jsonEncode(result.details);
      expect(detailsJson, isNot(contains('DO_NOT_LEAK_HIDDEN_SOURCE')));
      expect(detailsJson, isNot(contains('secret hidden behavior name')));
      expect(result.details['failures'], [
        {'index': 1, 'message': 'hidden verifier failure'},
      ]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'rejects hidden verifier traversal before writing any files',
    () async {
      final root = await Directory.systemTemp.createTemp('hidden_eval_path_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = await _scaffold(root);
      final validHidden = File(
        p.join(dir.path, 'test', '_hidden', 'answer_hidden_test.dart'),
      );
      final outside = File(p.join(root.path, 'outside.dart'));

      final result = await HiddenTestEvaluator(
        const VerifierFixture(
          files: {
            'test/_hidden/answer_hidden_test.dart':
                'valid file should not write',
            '../outside.dart': 'outside file should not write',
          },
          testPath: 'test/_hidden/answer_hidden_test.dart',
        ),
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.rationale, 'hidden verifier path rejected');
      expect(validHidden.existsSync(), isFalse);
      expect(outside.existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'rejects absolute hidden verifier paths',
    () async {
      final root = await Directory.systemTemp.createTemp('hidden_eval_abs_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = await _scaffold(root);
      final absolute = p.join(root.path, 'absolute_hidden_test.dart');

      final result = await HiddenTestEvaluator(
        VerifierFixture(
          files: {absolute: 'outside file should not write'},
          testPath: 'test/_hidden/answer_hidden_test.dart',
        ),
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(File(absolute).existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reference replacement rejects traversal before any write',
    () async {
      final root = await Directory.systemTemp.createTemp('reference_path_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = await _scaffold(root);
      final target = File(p.join(dir.path, 'lib', 'tmp.dart'));
      final original = target.readAsStringSync();
      final outside = File(p.join(root.path, 'outside.dart'));

      await expectLater(
        applyReferenceSolution(
          dir,
          const ReferenceFileSolution({
            'lib/tmp.dart': 'int answer() => 7;',
            '../outside.dart': 'outside file should not write',
          }),
        ),
        throwsArgumentError,
      );

      expect(target.readAsStringSync(), original);
      expect(outside.existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reference replacement rejects absolute paths',
    () async {
      final root = await Directory.systemTemp.createTemp('reference_abs_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = await _scaffold(root);
      final absolute = p.join(root.path, 'absolute.dart');

      await expectLater(
        applyReferenceSolution(
          dir,
          ReferenceFileSolution({absolute: 'outside file should not write'}),
        ),
        throwsArgumentError,
      );

      expect(File(absolute).existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
