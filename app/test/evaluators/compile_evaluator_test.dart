import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
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
  test('passes for clean Dart code', () async {
    final root = await Directory.systemTemp.createTemp('dart_arena_compile_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(
      p.join(dir.path, 'lib', 'tmp.dart'),
    ).writeAsStringSync('int answer() => 42;\n');

    expect(await WorkdirManager(root: root).prepare(dir), isA<PrepareOk>());
    final result = await const CompileEvaluator().evaluate(_ctx(dir));
    expect(result.passed, isTrue);
    expect(result.score, 1.0);

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'fails for code with syntax errors',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_compile_bad_',
      );
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
      Directory(p.join(dir.path, 'lib')).createSync();
      File(
        p.join(dir.path, 'lib', 'tmp.dart'),
      ).writeAsStringSync('int answer( => 42;');

      expect(await WorkdirManager(root: root).prepare(dir), isA<PrepareOk>());
      final result = await const CompileEvaluator().evaluate(_ctx(dir));
      expect(result.passed, isFalse);
      expect(result.score, 0.0);

      root.deleteSync(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'terminates analysis when output exceeds the compile evaluator limit',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_compile_output_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      final fakeDart = await _writeChattyExecutable(root);

      final result = await CompileEvaluator(
        dartExecutable: fakeDart.path,
        timeout: const Duration(seconds: 5),
        maxOutputChars: 32,
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'analysis output limit exceeded');
      expect(result.details['output_limit_exceeded'], isTrue);
      expect(result.details['max_output_chars'], 32);
      expect(result.details['exitCode'], -1);
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 10)),
  );
}

Future<File> _writeChattyExecutable(Directory root) async {
  final script = File(p.join(root.path, 'fake_dart_compile_chatty.sh'));
  await script.writeAsString('''
#!/bin/sh
i=0
while [ "\$i" -lt 100 ]; do
  printf '0123456789'
  i=\$((i + 1))
done
sleep 20
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
