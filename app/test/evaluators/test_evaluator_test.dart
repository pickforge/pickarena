import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:test/test.dart';
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

  test(
    'times out hanging tests and reports the timeout',
    () async {
      final dir = await _scaffold(
        libContents: 'int answer() => 41;\n',
        testContents: '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test('hangs', () => Completer<void>().future);
}
''',
      );
      final result = await TestEvaluator(
        timeout: const Duration(milliseconds: 200),
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'test process timed out');
      expect(result.details['timed_out'], isTrue);
      expect(result.details['timeout_ms'], 200);
      expect(result.details['exit_code'], -1);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'terminates tests that exceed the output limit',
    () async {
      final dir = await _scaffold(
        libContents: 'int answer() => 41;\n',
        testContents: '''
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('prints forever', () async {
    for (var i = 0; i < 128; i++) {
      stdout.writeln('x' * 512);
    }
    await Completer<void>().future;
  });
}
''',
      );
      final result = await TestEvaluator(
        timeout: const Duration(seconds: 60),
        maxOutputBytes: 2048,
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'test process output limit exceeded');
      expect(result.details['output_limit_exceeded'], isTrue);
      expect(result.details['max_output_bytes'], 2048);
      expect(result.details['timed_out'], isNull);
      expect(result.details['exit_code'], -1);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reports output limit when the test process exits after flooding output',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_test_eval_output_exit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      final fakeDart = await _writeChattyExitExecutable(root);

      final result = await TestEvaluator(
        dartExecutable: fakeDart.path,
        timeout: const Duration(seconds: 5),
        maxOutputBytes: 128,
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'test process output limit exceeded');
      expect(result.details['output_limit_exceeded'], isTrue);
      expect(result.details['max_output_bytes'], 128);
      expect(result.details['timed_out'], isNull);
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'cancels unused timeout timer after successful tests',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_eval_exit_parent_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final script = File(p.join(root.path, 'child.dart'));
      await script.writeAsString(r"""
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:path/path.dart' as p;

class _ChildTask extends BenchmarkTask {
  @override
  String get id => 'child';
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
  task: _ChildTask(),
);

Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('dart_arena_eval_exit_child_');
  try {
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: child_tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync('int answer() => 42;\n');
    Directory(p.join(dir.path, 'test')).createSync();
    File(p.join(dir.path, 'test', 'tmp_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:child_tmp/tmp.dart';

void main() {
  test('passes', () => expect(answer(), 42));
}
''');

    await WorkdirManager(root: root).prepare(dir);
    final result = await TestEvaluator(
      timeout: const Duration(seconds: 90),
    ).evaluate(_ctx(dir));
    if (!result.passed) {
      stderr.writeln(result.rationale);
      exitCode = 2;
      return;
    }
    stdout.writeln('ok');
  } finally {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
""");

      final process = await Process.start(
        'dart',
        ['--packages=.dart_tool/package_config.json', script.path],
        workingDirectory: Directory.current.path,
        runInShell: false,
      );
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutDone = process.stdout
          .transform(systemEncoding.decoder)
          .listen(stdoutBuffer.write)
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(systemEncoding.decoder)
          .listen(stderrBuffer.write)
          .asFuture<void>();
      final stopwatch = Stopwatch()..start();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          Process.killPid(process.pid);
          return -1;
        },
      );
      stopwatch.stop();
      await Future.wait([stdoutDone, stderrDone]);

      expect(
        exitCode,
        0,
        reason:
            'stdout:\n$stdoutBuffer\nstderr:\n$stderrBuffer\nelapsed: ${stopwatch.elapsed}',
      );
      expect(stdoutBuffer.toString(), contains('ok'));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

Future<File> _writeChattyExitExecutable(Directory root) async {
  final script = File(p.join(root.path, 'fake_dart_test_chatty_exit.sh'));
  await script.writeAsString('''
#!/bin/sh
i=0
while [ "\$i" -lt 100 ]; do
  printf '0123456789'
  i=\$((i + 1))
done
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
