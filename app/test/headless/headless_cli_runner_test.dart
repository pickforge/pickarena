import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/export/artifact_bundle.dart';
import 'package:dart_arena/headless/headless_benchmark_runner.dart';
import 'package:dart_arena/headless/headless_cli_runner.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/headless_fakes.dart';

const _weights = <String, double>{
  'smoke_generated_code': 1.0,
  'smoke_generated_file': 1.0,
};

class _HeadlessSmokeTask extends BenchmarkTask {
  @override
  String get id => 'phase7.headless_smoke';

  @override
  Category get category => Category.widgetTesting;

  @override
  Duration? get timeout => const Duration(seconds: 2);

  @override
  String get prompt => 'Generate a Dart function named headlessAnswer.';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml':
        'name: phase7_headless_smoke\nenvironment:\n'
        '  sdk: ">=3.5.0 <4.0.0"\n',
  };

  @override
  String get generatedCodePath => 'lib/headless_answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [
    _GeneratedCodePresentEvaluator(),
    _GeneratedFilePresentEvaluator(),
  ];
}

class _AgenticHeadlessSmokeTask extends _HeadlessSmokeTask {
  @override
  String get id => 'agentic.phase7.headless_smoke';

  @override
  BenchmarkTrack get track => BenchmarkTrack.agentic;
}

class _GeneratedCodePresentEvaluator implements Evaluator {
  const _GeneratedCodePresentEvaluator();

  @override
  String get id => 'smoke_generated_code';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final code = ctx.response.extractedCode ?? '';
    final passed = code.contains('headlessAnswer') && code.contains('phase7');
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
    );
  }
}

class _GeneratedFilePresentEvaluator implements Evaluator {
  const _GeneratedFilePresentEvaluator();

  @override
  String get id => 'smoke_generated_file';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final file = File(p.join(ctx.workDir.path, ctx.task.generatedCodePath));
    final text = await file.exists() ? await file.readAsString() : '';
    final passed = text.contains('headlessAnswer') && text.contains('phase7');
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
    );
  }
}

class _CapturingHeadlessBenchmarkRunner extends HeadlessBenchmarkRunner {
  HeadlessBenchmarkConfig? capturedConfig;

  @override
  Future<HeadlessBenchmarkResult> run(HeadlessBenchmarkConfig config) {
    capturedConfig = config;
    throw StateError('stop after capture');
  }
}

void main() {
  test('CLI --help emits exactly one JSON object', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runHeadlessCli(
      ['--help'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines, hasLength(1));
    final decoded = _expectSingleJsonObject(stdoutLines.single);
    expect(decoded['status'], 'help');
    expect(decoded['configFormat'], 'json');
    expect(
      decoded['usage'],
      'dart run --verbosity=error dart_arena:dart_arena_headless --config run.json',
    );
  });

  test(
    'dart run headless --help works without Flutter-only CLI imports',
    () async {
      final result = await Process.run('dart', [
        'run',
        '--verbosity=error',
        'dart_arena:dart_arena_headless',
        '--help',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stderr.toString(), isEmpty);
      final decoded = _expectProcessJsonObject(result.stdout);
      expect(decoded['status'], 'help');
      expect(
        decoded['usage'],
        'dart run --verbosity=error dart_arena:dart_arena_headless --config run.json',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'dart run headless failure emits exactly one stderr JSON object',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_cli_dart_run_fail_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final configFile = await _writeConfig(tmp, tasks: ['missing.task']);

      final result = await Process.run('dart', [
        'run',
        '--verbosity=error',
        'dart_arena:dart_arena_headless',
        '--config',
        configFile.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNot(0));
      expect(result.stdout.toString(), isEmpty);
      final decoded = _expectProcessJsonObject(result.stderr);
      expect(decoded['status'], 'failed');
      expect(decoded['error'], 'unknown task id: missing.task');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'dart run headless timeout exits promptly with one failure JSON',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_cli_process_timeout_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serveNeverCompletingChat(server));
      addTearDown(() async {
        await server.close(force: true);
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      const runId = 'cli-process-timeout-run';
      final configFile = await _writeConfig(
        tmp,
        runId: runId,
        tasks: ['bug.off_by_one_pagination'],
        provider: {
          'type': 'openai_compatible',
          'id': 'local_timeout',
          'displayName': 'Local Timeout',
          'baseUrl': 'http://127.0.0.1:${server.port}/v1',
          'models': ['timeout-model'],
        },
        timeoutSeconds: 1,
      );

      final stopwatch = Stopwatch()..start();
      final result = await Process.run(
        'dart',
        [
          'run',
          '--verbosity=error',
          'dart_arena:dart_arena_headless',
          '--config',
          configFile.path,
        ],
        workingDirectory: Directory.current.path,
      ).timeout(const Duration(seconds: 30));
      stopwatch.stop();

      expect(result.exitCode, isNot(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 25)));
      expect(result.stdout.toString(), isEmpty);
      final decoded = _expectProcessJsonObject(result.stderr);
      expect(decoded['status'], 'failed');
      expect(decoded['error'].toString(), contains('timed out'));
      expect(
        Directory(
          p.join(tmp.path, 'bundles', runBundleDirectoryName(runId)),
        ).existsSync(),
        isFalse,
      );

      final databaseFile = File(p.join(tmp.path, 'dart_arena.sqlite'));
      if (databaseFile.existsSync()) {
        final db = AppDatabase(NativeDatabase(databaseFile));
        addTearDown(db.close);
        final storedRun = await RunDao(db).runById(runId);
        expect(storedRun?.completedAt, isNull);
      }
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'dart run headless prepare timeout returns worker JSON before hard kill',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_cli_prepare_timeout_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serveSuccessfulStreamingChat(server));
      final dartExecutable = await _resolveDartExecutable();
      final fakeBin = Directory(p.join(tmp.path, 'fake_bin'))
        ..createSync(recursive: true);
      final marker = File(p.join(tmp.path, 'prepare-marker.txt'));
      final childPidFile = File(p.join(tmp.path, 'prepare-child.pid'));
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'));
      await _writeHangingDartExecutable(
        fakeBin,
        marker,
        childPidFile,
        workdirRoot,
        File(dartExecutable),
      );
      addTearDown(() async {
        await server.close(force: true);
        final childPid = await _readPid(childPidFile);
        if (childPid != null && await _isPidRunning(childPid)) {
          Process.killPid(childPid, ProcessSignal.sigkill);
        }
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      const runId = 'cli-prepare-timeout-run';
      final configFile = await _writeConfig(
        tmp,
        runId: runId,
        tasks: ['bug.off_by_one_pagination'],
        provider: {
          'type': 'openai_compatible',
          'id': 'local_prepare_timeout',
          'displayName': 'Local Prepare Timeout',
          'baseUrl': 'http://127.0.0.1:${server.port}/v1',
          'models': ['prepare-timeout-model'],
        },
        timeoutSeconds: 1,
      );
      final originalPath = Platform.environment['PATH'] ?? '';

      final stopwatch = Stopwatch()..start();
      final result = await Process.run(
        dartExecutable,
        [
          'run',
          '--verbosity=error',
          'dart_arena:dart_arena_headless',
          '--config',
          configFile.path,
        ],
        workingDirectory: Directory.current.path,
        environment: {'PATH': '${fakeBin.path}:$originalPath'},
      ).timeout(const Duration(seconds: 30));
      stopwatch.stop();

      expect(result.exitCode, isNot(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 25)));
      expect(result.stdout.toString(), isEmpty);
      final decoded = _expectProcessJsonObject(result.stderr);
      expect(decoded['status'], 'failed');
      expect(
        decoded['error'].toString(),
        contains('Headless benchmark run timed out'),
      );
      expect(decoded['error'].toString(), isNot(contains('hard timeout')));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
      final childPid = await _readPid(childPidFile);
      expect(childPid, isNotNull);
      if (childPid != null) {
        await _waitForPidToStop(childPid);
        expect(await _isPidRunning(childPid), isFalse);
      }

      final databaseFile = File(p.join(tmp.path, 'dart_arena.sqlite'));
      if (databaseFile.existsSync()) {
        final db = AppDatabase(NativeDatabase(databaseFile));
        addTearDown(db.close);
        final storedRun = await RunDao(db).runById(runId);
        expect(storedRun?.completedAt, isNull);
      }
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'success emits one stdout JSON object and creates a Phase 6 bundle',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_cli_ok_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final configFile = await _writeConfig(tmp, runId: 'cli-success-run');
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final exitCode = await runHeadlessCli(
        ['--config', configFile.path],
        dependencies: _dependencies(
          providerBuilder: (config, _) => DeterministicFakeProvider(
            providerId: config.id,
            providerDisplayName: config.displayName,
            modelId: config.models.single,
          ),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(stdoutLines, hasLength(1));
      final decoded = _expectSingleJsonObject(stdoutLines.single);
      expect(decoded['status'], 'completed');
      expect(decoded['runId'], 'cli-success-run');
      expect(decoded['taskRunCount'], 1);
      expect(decoded['evaluationCount'], 2);
      expect(decoded['bundleWarningCount'], 0);
      final bundlePath = decoded['bundlePath']! as String;
      expect(Directory(bundlePath).existsSync(), isTrue);
      expect(File(p.join(bundlePath, 'manifest.json')).existsSync(), isTrue);
      expect(
        File(p.join(bundlePath, 'run_results.v1.json')).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'failed provider emits one stderr JSON object and no completed bundle',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_cli_fail_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      const runId = 'cli-failed-run';
      final configFile = await _writeConfig(tmp, runId: runId);
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final exitCode = await runHeadlessCli(
        ['--config', configFile.path],
        dependencies: _dependencies(
          providerBuilder: (config, _) => FailingFakeProvider(
            providerId: config.id,
            providerDisplayName: config.displayName,
            modelId: config.models.single,
          ),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, isNot(0));
      expect(stdoutLines, isEmpty);
      expect(stderrLines, hasLength(1));
      final decoded = _expectSingleJsonObject(stderrLines.single);
      expect(decoded['status'], 'failed');
      expect(decoded['error'], contains('Headless run failed'));
      expect(decoded['error'], contains('deterministic provider failure'));
      expect(
        Directory(
          p.join(tmp.path, 'bundles', runBundleDirectoryName(runId)),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'missing env secret reports only the environment variable name',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_cli_env_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final configFile = await _writeConfig(
        tmp,
        provider: {
          'type': 'openai',
          'models': ['gpt-5.5'],
          'apiKeyEnv': 'SECRET_KEY',
        },
      );
      final stderrLines = <String>[];

      final exitCode = await runHeadlessCli(
        ['--config', configFile.path],
        dependencies: _dependencies(environmentReader: (_) => null),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, isNot(0));
      final decoded = _expectSingleJsonObject(stderrLines.single);
      expect(decoded['error'], 'missing environment variable: SECRET_KEY');
      expect(decoded['error'], isNot(contains('secret-value')));
    },
  );

  test('configured provider apiKeyEnv is denied from subprocesses', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_cli_env_deny_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final configFile = await _writeConfig(
      tmp,
      provider: {
        'type': 'openai_compatible',
        'id': 'local',
        'displayName': 'Local',
        'baseUrl': 'http://127.0.0.1:11434/v1',
        'apiKeyEnv': 'SECRET_KEY',
        'models': ['local-model'],
      },
    );
    final runner = _CapturingHeadlessBenchmarkRunner();

    final exitCode = await runHeadlessCli(
      ['--config', configFile.path],
      dependencies: _dependencies(
        runner: runner,
        environmentReader: (name) => name == 'SECRET_KEY' ? 'secret' : null,
      ),
      stdoutWriter: (_) {},
      stderrWriter: (_) {},
    );

    expect(exitCode, 1);
    expect(
      runner.capturedConfig!.workdirManager.deniedEnvironmentKeys,
      contains('SECRET_KEY'),
    );
  });

  test('unknown task fails clearly', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_cli_task_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final configFile = await _writeConfig(tmp, tasks: ['missing.task']);
    final stderrLines = <String>[];

    final exitCode = await runHeadlessCli(
      ['--config', configFile.path],
      dependencies: _dependencies(),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, isNot(0));
    final decoded = _expectSingleJsonObject(stderrLines.single);
    expect(decoded['error'], 'unknown task id: missing.task');
  });

  test(
    'agentic task selection runs through configured agent harness',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_cli_agentic_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final configFile = await _writeConfig(
        tmp,
        runId: 'cli-agentic-run',
        tasks: ['agentic.phase7.headless_smoke'],
      );
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      late DeterministicFakeAgentHarness harness;

      final exitCode = await runHeadlessCli(
        ['--config', configFile.path],
        dependencies: _dependencies(
          taskRegistryBuilder: () => TaskRegistry()
            ..register(_HeadlessSmokeTask())
            ..register(_AgenticHeadlessSmokeTask()),
          providerBuilder: (config, _) => DeterministicFakeProvider(
            providerId: config.id,
            providerDisplayName: config.displayName,
            modelId: config.models.single,
          ),
          agentHarnessBuilder: (config) {
            harness = DeterministicFakeAgentHarness(
              harnessId: config.providers.single.id,
              modelId: config.providers.single.models.single,
            );
            return [harness];
          },
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(stdoutLines, hasLength(1));
      final decoded = _expectSingleJsonObject(stdoutLines.single);
      expect(decoded['status'], 'completed');
      expect(decoded['runId'], 'cli-agentic-run');
      expect(decoded['taskRunCount'], 1);
      expect(decoded['evaluationCount'], 3);
      expect(decoded['bundleWarningCount'], 0);
      expect(harness.runCount, 1);
    },
  );

  test('provider errors redact configured secret values', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_cli_redact_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final configFile = await _writeConfig(
      tmp,
      provider: {
        'type': 'openai',
        'models': ['gpt-5.5'],
        'apiKeyEnv': 'OPENAI_API_KEY',
      },
    );
    final stderrLines = <String>[];

    final exitCode = await runHeadlessCli(
      ['--config', configFile.path],
      dependencies: _dependencies(
        environmentReader: (_) => 'secret-value',
        providerBuilder: (_, __) => throw StateError('boom secret-value'),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, isNot(0));
    final decoded = _expectSingleJsonObject(stderrLines.single);
    expect(decoded['error'], contains('[redacted]'));
    expect(decoded['error'], isNot(contains('secret-value')));
  });
}

Map<String, Object?> _expectSingleJsonObject(String output) {
  expect(output, output.trim());
  expect(output.startsWith('{'), isTrue);
  expect(output.endsWith('}'), isTrue);
  final decoded = jsonDecode(output);
  expect(decoded, isA<Map<String, Object?>>());
  return decoded as Map<String, Object?>;
}

Map<String, Object?> _expectProcessJsonObject(Object? output) {
  final text = output.toString();
  final trimmed = text.trim();
  expect(trimmed, isNotEmpty);
  expect(text, anyOf(trimmed, '$trimmed\n'));
  return _expectSingleJsonObject(trimmed);
}

HeadlessCliDependencies _dependencies({
  HeadlessCliEnvironmentReader environmentReader = _emptyEnv,
  HeadlessCliProviderBuilder? providerBuilder,
  HeadlessCliTaskRegistryBuilder? taskRegistryBuilder,
  HeadlessCliAgentHarnessBuilder? agentHarnessBuilder,
  HeadlessBenchmarkRunner? runner,
}) {
  return HeadlessCliDependencies(
    environmentReader: environmentReader,
    providerBuilder:
        providerBuilder ??
        (config, _) => DeterministicFakeProvider(
          providerId: config.id,
          providerDisplayName: config.displayName,
          modelId: config.models.single,
        ),
    taskRegistryBuilder:
        taskRegistryBuilder ??
        (() => TaskRegistry()..register(_HeadlessSmokeTask())),
    agentHarnessBuilder: agentHarnessBuilder ?? (_) => const [],
    now: () => DateTime.utc(2026, 5, 30, 12),
    provenanceEnvironmentProviderBuilder: () =>
        const FixedRunProvenanceEnvironmentProvider(),
    exportEnvironmentProvider: () async => const {'hostPlatform': 'test-os'},
    exportAppVersionProvider: () async => '1.0.0+headless-cli-test',
    runner: runner ?? const HeadlessBenchmarkRunner(),
  );
}

String? _emptyEnv(String name) => null;

Future<File> _writeConfig(
  Directory tmp, {
  String runId = 'cli-run',
  List<String> tasks = const ['phase7.headless_smoke'],
  Map<String, Object?> provider = const {
    'type': 'droid',
    'models': ['fake-headless-model'],
  },
  int timeoutSeconds = 30,
}) async {
  final file = File(p.join(tmp.path, 'run.json'));
  await file.writeAsString(
    jsonEncode({
      'runId': runId,
      'name': 'CLI smoke',
      'tasks': tasks,
      'providers': [provider],
      'evaluatorWeights': _weights,
      'maxConcurrency': 1,
      'trialsPerTask': 1,
      'useReferencePlan': false,
      'workdirRoot': 'workdirs',
      'outputDir': 'bundles',
      'databasePath': 'dart_arena.sqlite',
      'timeoutSeconds': timeoutSeconds,
    }),
  );
  return file;
}

Future<void> _serveNeverCompletingChat(HttpServer server) async {
  await for (final request in server) {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('text', 'event-stream');
    try {
      while (true) {
        response.write(': keepalive\n\n');
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } on Object {
      try {
        await response.close();
      } on Object {
        return;
      }
    }
  }
}

Future<void> _serveSuccessfulStreamingChat(HttpServer server) async {
  await for (final request in server) {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('text', 'event-stream');
    final data = jsonEncode({
      'choices': [
        {
          'delta': {
            'content': "```dart\nString headlessAnswer() => 'phase7';\n```",
          },
        },
      ],
    });
    response.write('data: $data\n\n');
    response.write('data: [DONE]\n\n');
    await response.close();
  }
}

Future<File> _writeHangingDartExecutable(
  Directory fakeBin,
  File marker,
  File childPidFile,
  Directory workdirRoot,
  File realDart,
) async {
  final script = File(p.join(fakeBin.path, 'dart'));
  await script.writeAsString('''
#!/bin/sh
case "\$PWD" in
  ${_shQuote(p.join(workdirRoot.path, 'runs'))}/*) ;;
  *) exec ${_shQuote(realDart.path)} "\$@" ;;
esac
trap 'exit 143' TERM
echo started >> ${_shQuote(marker.path)}
sleep 20 </dev/null >/dev/null 2>&1 &
child=\$!
echo "\$child" > ${_shQuote(childPidFile.path)}
wait "\$child"
status=\$?
if [ "\$status" -eq 0 ]; then
  echo done >> ${_shQuote(marker.path)}
fi
exit "\$status"
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

String _shQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

Future<String> _resolveDartExecutable() async {
  final result = await Process.run('which', ['dart']);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout.toString().trim().split('\n').first;
}

Future<int?> _readPid(File file) async {
  if (!await file.exists()) return null;
  return int.tryParse((await file.readAsString()).trim());
}

Future<void> _waitForPidToStop(int pid) async {
  for (var i = 0; i < 20; i++) {
    if (!await _isPidRunning(pid)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<bool> _isPidRunning(int pid) async {
  if (Platform.isWindows) return false;
  final result = await Process.run('ps', ['-p', '$pid', '-o', 'stat=']);
  if (result.exitCode != 0) return false;
  final stat = result.stdout.toString().trim();
  return stat.isNotEmpty && !stat.startsWith('Z');
}
