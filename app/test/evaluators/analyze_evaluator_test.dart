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
  test(
    'clean code scores 1.0 and passes',
    () async {
      final dir = await _scaffold('int answer() => 42;\n');
      final r = await const AnalyzeEvaluator().evaluate(_ctx(dir));
      expect(r.passed, isTrue);
      expect(r.score, 1.0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'code with errors scores 0.0 and fails',
    () async {
      final dir = await _scaffold('int answer( => 42;');
      final r = await const AnalyzeEvaluator().evaluate(_ctx(dir));
      expect(r.passed, isFalse);
      expect(r.score, 0.0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'warning-only code scores between 0 and 1',
    () async {
      final dir = await _scaffold('''
int answer() {
  final x = 1;
  return 42;
}
''');
      final r = await const AnalyzeEvaluator().evaluate(_ctx(dir));
      expect(r.passed, isTrue);
      expect(r.score, lessThan(1.0));
      expect(r.score, greaterThan(0.0));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'times out hanging analyze process and kills its process tree',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_analyze_timeout_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      final marker = File(p.join(root.path, 'marker.txt'));
      final fakeDart = await _writeHangingExecutable(root, marker);

      final result = await AnalyzeEvaluator(
        dartExecutable: fakeDart.path,
        timeout: const Duration(milliseconds: 120),
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'analyze process timed out');
      expect(result.details['timed_out'], isTrue);
      expect(result.details['timeout_ms'], 120);
      expect(result.details['exit_code'], -1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'terminates analyze process trees that exceed the process limit',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_analyze_process_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      final marker = File(p.join(root.path, 'marker.txt'));
      final fakeDart = await _writeForkingExecutable(root, marker);

      final result = await AnalyzeEvaluator(
        dartExecutable: fakeDart.path,
        timeout: const Duration(seconds: 5),
        maxProcesses: 1,
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'analyze process limit exceeded');
      expect(result.details['process_limit_exceeded'], isTrue);
      expect(result.details['max_processes'], 1);
      expect(result.details['observed_processes'], greaterThan(1));
      expect(result.details['exit_code'], -1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'isolates home and user config environment for analyze process',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_analyze_isolated_home_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      final envFile = File(p.join(root.path, 'env.txt'));
      final fakeDart = await _writeEnvDumpExecutable(root, envFile);

      final result = await AnalyzeEvaluator(
        dartExecutable: fakeDart.path,
        timeout: const Duration(seconds: 5),
      ).evaluate(_ctx(dir));

      expect(result.passed, isTrue);
      final env = await envFile.readAsString();
      expect(env, contains('HOME=${dir.path}'));
      expect(env, contains('USERPROFILE=${dir.path}'));
      expect(env, contains('XDG_CONFIG_HOME=${p.join(dir.path, '.config')}'));
      expect(env, contains('XDG_CACHE_HOME=${p.join(dir.path, '.cache')}'));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'terminates analyze processes that exceed the memory limit',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_analyze_memory_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      final marker = File(p.join(root.path, 'marker.txt'));
      final fakeDart = await _writeSleepingExecutable(root, marker);

      final result = await AnalyzeEvaluator(
        dartExecutable: fakeDart.path,
        timeout: const Duration(seconds: 5),
        maxMemoryMb: 1,
      ).evaluate(_ctx(dir));

      expect(result.passed, isFalse);
      expect(result.score, 0.0);
      expect(result.rationale, 'analyze memory limit exceeded');
      expect(result.details['memory_limit_exceeded'], isTrue);
      expect(result.details['max_memory_mb'], 1);
      expect(result.details['observed_memory_mb'], greaterThan(1));
      expect(result.details['exit_code'], -1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 10)),
  );
}

Future<File> _writeHangingExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_dart_analyze_hang.sh'));
  await script.writeAsString('''
#!/bin/sh
echo started >> '${marker.path}'
sleep 20 && echo done >> '${marker.path}'
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeForkingExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_dart_analyze_fork.sh'));
  await script.writeAsString('''
#!/bin/sh
echo started >> '${marker.path}'
sleep 20 &
sleep 20 &
sleep 20 &
wait
echo done >> '${marker.path}'
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeSleepingExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_dart_analyze_sleep.sh'));
  await script.writeAsString('''
#!/bin/sh
echo started >> '${marker.path}'
sleep 20
echo done >> '${marker.path}'
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeEnvDumpExecutable(Directory root, File envFile) async {
  final script = File(p.join(root.path, 'fake_dart_analyze_env.sh'));
  await script.writeAsString('''
#!/bin/sh
env > '${envFile.path}'
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
