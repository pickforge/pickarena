import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'DroidAgentHarness invokes droid exec in the workspace with tools enabled',
    () async {
      final workspace = await Directory.systemTemp.createTemp('droid_agent_');
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      late String seenExecutable;
      late List<String> seenArgs;
      late Directory seenWorkspace;
      late Duration seenTimeout;
      final harness = DroidAgentHarness(
        droidPath: '/bin/droid',
        runner: (executable, args, workspace, timeout) async {
          seenExecutable = executable;
          seenArgs = args;
          seenWorkspace = workspace;
          seenTimeout = timeout;
          return const AgentRunResult(
            status: AgentRunStatus.success,
            stdoutPreview: 'done',
            stderrPreview: '',
            exitCode: 0,
            latency: Duration(milliseconds: 5),
          );
        },
      );

      final result = await harness.run(
        workspace: workspace,
        instruction: 'Fix the bug.',
        modelId: 'gpt-5.5',
        timeout: const Duration(minutes: 3),
      );

      expect(
        result.succeeded,
        isTrue,
        reason:
            'stdout=${result.stdoutPreview} stderr=${result.stderrPreview} '
            'metadata=${result.metadata}',
      );
      expect(seenExecutable, '/bin/droid');
      expect(seenWorkspace.path, workspace.path);
      expect(seenTimeout, const Duration(minutes: 3));
      expect(seenArgs, containsAllInOrder(['--auto', 'high']));
      expect(seenArgs, containsAllInOrder(['exec', '--output-format', 'text']));
      expect(seenArgs, containsAllInOrder(['--model', 'gpt-5.5']));
      expect(seenArgs, isNot(contains('--enabled-tools')));
      expect(seenArgs.last, contains('Fix the bug.'));
      expect(seenArgs.last, isNot(contains('Do not use tools')));
    },
  );

  test(
    'DroidAgentHarness wraps default runner with generated code sandbox metadata',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'droid_agent_sandbox_',
      );
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      final script = File(p.join(workspace.path, 'fake_droid_sandbox.sh'));
      await script.writeAsString(r'''
#!/bin/sh
printf '%s' "$DROID_SANDBOX_MARKER" > sandbox-marker.txt
''');
      final chmod = await Process.run('chmod', ['+x', script.path]);
      expect(chmod.exitCode, 0);

      final sandbox = _RecordingGeneratedCodeSandbox();
      final harness = DroidAgentHarness(
        droidPath: script.path,
        generatedCodeSandbox: sandbox,
      );
      final result = await harness.run(
        workspace: workspace,
        instruction: 'use sandbox marker',
        modelId: 'gpt-5.5',
        timeout: const Duration(seconds: 2),
      );

      expect(
        result.succeeded,
        isTrue,
        reason:
            'stdout=${result.stdoutPreview} stderr=${result.stderrPreview} '
            'metadata=${result.metadata}',
      );
      expect(sandbox.seenExecutable, script.path);
      expect(sandbox.seenArguments, containsAllInOrder(['exec', '--auto']));
      expect(sandbox.seenArguments, containsAllInOrder(['--model', 'gpt-5.5']));
      expect(sandbox.seenArguments?.last, contains('use sandbox marker'));
      expect(sandbox.seenWorkingDirectory, workspace.path);
      expect(sandbox.seenAllowInternet, isTrue);
      expect(sandbox.seenResourceLimits, isNull);
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      final factoryDir = Directory(p.join(home, '.factory'));
      expect(
        sandbox.seenExtraReadOnlyPaths,
        factoryDir.existsSync() ? [factoryDir.path] : isEmpty,
      );
      expect(
        await File(p.join(workspace.path, 'sandbox-marker.txt')).readAsString(),
        'fake-sandbox',
      );
      expect(result.metadata['runtimeBoundary'], {
        'enforced': true,
        'backend': 'fake-backend',
      });
      for (final key in const [
        'args',
        'arguments',
        'command',
        'instruction',
        'prompt',
        'model',
        'modelId',
        'environment',
        'wrappedExecutable',
        'bwrapArgs',
        'workingDirectory',
      ]) {
        expect(result.metadata, isNot(contains(key)));
      }
      final encodedMetadata = jsonEncode(result.metadata);
      expect(encodedMetadata, isNot(contains('use sandbox marker')));
      expect(encodedMetadata, isNot(contains('gpt-5.5')));
      expect(encodedMetadata, isNot(contains('DROID_SANDBOX_MARKER')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test('DroidAgentHarness bounds stdout and stderr previews', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'droid_agent_trim_',
    );
    addTearDown(() async {
      if (await workspace.exists()) await workspace.delete(recursive: true);
    });

    final harness = DroidAgentHarness(
      maxPreviewChars: 4,
      runner: (_, _, _, _) async => const AgentRunResult(
        status: AgentRunStatus.failure,
        stdoutPreview: 'abcdef',
        stderrPreview: '123456',
        exitCode: 1,
        latency: Duration(milliseconds: 1),
      ),
    );

    final result = await harness.run(
      workspace: workspace,
      instruction: 'x',
      modelId: 'm',
      timeout: const Duration(seconds: 1),
    );

    expect(result.stdoutPreview, 'cdef');
    expect(result.stderrPreview, '3456');
  });

  test(
    'DroidAgentHarness scrubs denied environment keys',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'droid_agent_env_',
      );
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      final script = File(p.join(workspace.path, 'fake_droid_env.sh'));
      await script.writeAsString('''
#!/bin/sh
pwd > cwd.txt
printf '%s\n' "\$PWD" > pwd.txt
env > env.txt
''');
      final chmod = await Process.run('chmod', ['+x', script.path]);
      expect(chmod.exitCode, 0);

      final harness = DroidAgentHarness(droidPath: script.path);
      final result = await harness.run(
        workspace: workspace,
        instruction: 'x',
        modelId: 'm',
        timeout: const Duration(seconds: 2),
        deniedEnvironmentKeys: const ['HOME'],
      );

      expect(result.succeeded, isTrue);
      expect(result.metadata, isNot(contains('runtimeBoundary')));
      expect(
        (await File(p.join(workspace.path, 'cwd.txt')).readAsString()).trim(),
        workspace.path,
      );
      expect(
        (await File(p.join(workspace.path, 'pwd.txt')).readAsString()).trim(),
        workspace.path,
      );
      final env = await File(p.join(workspace.path, 'env.txt')).readAsString();
      expect(
        env.split('\n').where((line) => line.startsWith('HOME=')),
        isEmpty,
      );
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'DroidAgentHarness launches long workspaces through a short cwd proxy',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'droid_agent_long_root_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      var workspace = root;
      for (var i = 0; i < 6; i++) {
        workspace = Directory(
          p.join(
            workspace.path,
            'very_long_workspace_segment_for_droid_proxy_$i',
          ),
        );
      }
      await workspace.create(recursive: true);

      final script = File(p.join(workspace.path, 'fake_droid_cwd.sh'));
      await script.writeAsString(r'''
#!/bin/sh
if [ ${#PWD} -gt 160 ]; then
  exit 1
fi
printf '%s\n' "$PWD" > pwd.txt
printf changed > marker.txt
''');
      final chmod = await Process.run('chmod', ['+x', script.path]);
      expect(chmod.exitCode, 0);

      final harness = DroidAgentHarness(droidPath: script.path);
      final result = await harness.run(
        workspace: workspace,
        instruction: 'x',
        modelId: 'm',
        timeout: const Duration(seconds: 2),
      );

      expect(result.succeeded, isTrue);
      expect(result.metadata['cwd_proxy_used'], isTrue);
      expect(
        await File(p.join(workspace.path, 'marker.txt')).readAsString(),
        {'changed'}.single,
      );
      final pwd = await File(p.join(workspace.path, 'pwd.txt')).readAsString();
      expect(pwd.trim().length, lessThanOrEqualTo(160));
      expect(pwd.trim(), isNot(workspace.path));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'DroidAgentHarness Bubblewrap probe blocks host file reads',
    () async {
      await _skipUnlessBubblewrapAvailable();
      final root = await Directory.systemTemp.createTemp('droid_agent_bwrap_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workspace = Directory(p.join(root.path, 'workspace'));
      await workspace.create();
      final hostSecret = File(p.join(root.path, 'host-secret.txt'));
      await hostSecret.writeAsString('secret-token-value');

      final script = File(p.join(workspace.path, 'fake_droid_bwrap.sh'));
      await script.writeAsString('''
#!/bin/sh
if cat ${_shellSingleQuoted(hostSecret.path)} >/dev/null 2>&1; then
  echo host secret readable >&2
  exit 7
fi
printf ok > workdir-write.txt
''');
      final chmod = await Process.run('chmod', ['+x', script.path]);
      expect(chmod.exitCode, 0);

      final harness = DroidAgentHarness(
        droidPath: script.path,
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
      );
      final result = await harness.run(
        workspace: workspace,
        instruction: 'write inside workspace',
        modelId: 'm',
        timeout: const Duration(seconds: 5),
      );

      expect(
        result.succeeded,
        isTrue,
        reason:
            'stdout=${result.stdoutPreview} stderr=${result.stderrPreview} '
            'metadata=${result.metadata}',
      );
      expect(result.stderrPreview, isNot(contains('host secret readable')));
      expect(
        await File(p.join(workspace.path, 'workdir-write.txt')).readAsString(),
        'ok',
      );
      expect(result.metadata['runtimeBoundary'], {
        'enforced': true,
        'backend': bubblewrapGeneratedCodeSandboxBackend,
      });
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'DroidAgentHarness timeout terminates spawned child processes',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'droid_agent_tree_',
      );
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      final script = File(p.join(workspace.path, 'fake_droid.sh'));
      await script.writeAsString('''
#!/bin/sh
(sleep 30) &
echo \$! > child.pid
wait
''');
      final chmod = await Process.run('chmod', ['+x', script.path]);
      expect(chmod.exitCode, 0);

      final harness = DroidAgentHarness(droidPath: script.path);
      final result = await harness.run(
        workspace: workspace,
        instruction: 'x',
        modelId: 'm',
        timeout: const Duration(milliseconds: 200),
      );

      expect(result.status, AgentRunStatus.timeout);
      final childPid = int.parse(
        File(p.join(workspace.path, 'child.pid')).readAsStringSync().trim(),
      );

      for (var i = 0; i < 20; i++) {
        if (!await _pidIsRunning(childPid)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await _pidIsRunning(childPid), isFalse);
    },
    skip: Platform.isWindows ? 'POSIX process-tree assertion' : false,
  );

  test(
    'DroidAgentHarness terminates output-flooding process',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'droid_agent_output_flood_',
      );
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      final script = File(p.join(workspace.path, 'fake_droid_flood.sh'));
      await script.writeAsString('''
#!/bin/sh
while :; do
  printf '0123456789abcdef0123456789abcdef\\n'
done
''');
      final chmod = await Process.run('chmod', ['+x', script.path]);
      expect(chmod.exitCode, 0);

      final harness = DroidAgentHarness(
        droidPath: script.path,
        maxPreviewChars: 128,
        maxProcessOutputChars: 128,
      );
      final result = await harness.run(
        workspace: workspace,
        instruction: 'x',
        modelId: 'm',
        timeout: const Duration(seconds: 5),
      );

      expect(result.status, AgentRunStatus.failure);
      expect(result.stdoutPreview.length, lessThanOrEqualTo(128));
      expect(
        result.stderrPreview,
        contains('agent harness output exceeded 128 characters'),
      );
      expect(result.metadata, containsPair('output_limit_exceeded', true));
      expect(result.metadata, containsPair('max_output_chars', 128));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 8)),
  );
}

class _RecordingGeneratedCodeSandbox extends GeneratedCodeSandbox {
  String? seenExecutable;
  List<String>? seenArguments;
  String? seenWorkingDirectory;
  Map<String, String>? seenEnvironment;
  bool? seenAllowInternet;
  SandboxResourceLimits? seenResourceLimits;
  List<String>? seenExtraReadOnlyPaths;

  @override
  String get backend => 'fake-backend';

  @override
  Future<SandboxedProcessStart> wrapProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
    required bool allowInternet,
    SandboxResourceLimits? resourceLimits,
    Iterable<String> extraReadOnlyPaths = const [],
  }) async {
    seenExecutable = executable;
    seenArguments = List.unmodifiable(arguments);
    seenWorkingDirectory = workingDirectory;
    seenEnvironment = Map.unmodifiable(environment);
    seenAllowInternet = allowInternet;
    seenResourceLimits = resourceLimits;
    seenExtraReadOnlyPaths = List.unmodifiable(extraReadOnlyPaths);
    return SandboxedProcessStart(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: {...environment, 'DROID_SANDBOX_MARKER': 'fake-sandbox'},
    );
  }
}

Future<void> _skipUnlessBubblewrapAvailable() async {
  try {
    await BubblewrapGeneratedCodeSandbox.ensureAvailable();
  } on Object catch (error) {
    markTestSkipped(error.toString());
  }
}

String _shellSingleQuoted(String value) =>
    "'${value.replaceAll("'", "'\"'\"'")}'";

Future<bool> _pidIsRunning(int pid) async {
  final result = await Process.run('ps', ['-p', '$pid', '-o', 'stat=']);
  if (result.exitCode != 0) return false;
  final stat = result.stdout.toString().trim();
  return stat.isNotEmpty && !stat.startsWith('Z');
}
