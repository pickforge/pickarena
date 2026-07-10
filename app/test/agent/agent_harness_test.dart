import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/agent/command_template_agent_harness.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/agent/minimal_agent_harness.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MinimalAgentHarness', () {
    test(
      'runs scripted bash steps and finishes after editing the workspace',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final provider = _ScriptedStreamingProvider([
          '```bash\nprintf done > result.txt\n```',
          '```bash\ntest -f result.txt\n```',
          'FINISH',
        ]);
        final sandbox = _RecordingGeneratedCodeSandbox();
        final harness = MinimalAgentHarness(
          provider: provider,
          harnessId: 'minimal-test',
          generatedCodeSandbox: sandbox,
        );

        final result = await harness.run(
          workspace: workspace,
          instruction: 'Write done to result.txt.',
          modelId: 'fake',
          timeout: const Duration(seconds: 2),
          allowInternet: false,
        );

        expect(result.succeeded, isTrue);
        expect(result.metadata['terminal_reason'], 'finished');
        expect(result.metadata['step_count'], 2);
        expect(result.promptTokens, 6);
        expect(result.completionTokens, 9);
        expect(
          await File(p.join(workspace.path, 'result.txt')).readAsString(),
          'done',
        );
        expect(provider.prompts[1], contains('Previous bash command:'));
        expect(provider.prompts[1], contains('exit code: 0'));
        expect(sandbox.seenExecutable, 'bash');
        expect(sandbox.seenArguments, [
          '--noprofile',
          '--norc',
          '-c',
          'test -f result.txt',
        ]);
        expect(sandbox.seenWorkingDirectory, workspace.path);
        expect(sandbox.seenAllowInternet, isFalse);
        expect(sandbox.seenEnvironment!['HOME'], workspace.path);
        expect(result.metadata['runtimeBoundary'], {
          'enforced': true,
          'backend': 'fake-backend',
        });
      },
      skip: Platform.isWindows ? 'bash harness requires POSIX shell' : false,
    );

    test(
      'stops when the configured step limit is reached',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final harness = MinimalAgentHarness(
          provider: _ScriptedStreamingProvider([
            '```bash\nprintf one > one.txt\n```',
            '```bash\nprintf two > two.txt\n```',
          ]),
          harnessId: 'minimal-test',
          maxSteps: 1,
        );

        final result = await harness.run(
          workspace: workspace,
          instruction: 'Write files.',
          modelId: 'fake',
          timeout: const Duration(seconds: 2),
        );

        expect(result.status, AgentRunStatus.failure);
        expect(result.metadata['terminal_reason'], 'max_steps');
        expect(result.metadata['step_count'], 1);
        expect(File(p.join(workspace.path, 'one.txt')).existsSync(), isTrue);
        expect(File(p.join(workspace.path, 'two.txt')).existsSync(), isFalse);
      },
      skip: Platform.isWindows ? 'bash harness requires POSIX shell' : false,
    );

    test('reports an unenforced host boundary', () async {
      final workspace = await Directory.systemTemp.createTemp('minimal_agent_');
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      final result =
          await MinimalAgentHarness(
            provider: _ScriptedStreamingProvider(['FINISH']),
            harnessId: 'minimal-test',
          ).run(
            workspace: workspace,
            instruction: 'Finish.',
            modelId: 'fake',
            timeout: const Duration(seconds: 2),
          );

      expect(result.metadata['runtimeBoundary'], {'enforced': false});
    });

    test('fails closed when a required sandbox is unavailable', () async {
      final workspace = await Directory.systemTemp.createTemp('minimal_agent_');
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });
      final provider = _ScriptedStreamingProvider(['FINISH']);

      final result =
          await MinimalAgentHarness(
            provider: provider,
            harnessId: 'minimal-test',
            requireGeneratedCodeSandbox: true,
          ).run(
            workspace: workspace,
            instruction: 'Finish.',
            modelId: 'fake',
            timeout: const Duration(seconds: 2),
          );

      expect(result.status, AgentRunStatus.failure);
      expect(result.metadata['terminal_reason'], 'sandbox_required');
      expect(provider.prompts, isEmpty);
    });

    test(
      'stops the bash subprocess when the wall-clock timeout expires',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final harness = MinimalAgentHarness(
          provider: _ScriptedStreamingProvider(['```bash\nsleep 1\n```']),
          harnessId: 'minimal-test',
        );

        final result = await harness.run(
          workspace: workspace,
          instruction: 'Wait.',
          modelId: 'fake',
          timeout: const Duration(milliseconds: 30),
        );

        expect(result.status, AgentRunStatus.timeout);
        expect(result.metadata['terminal_reason'], 'timeout');
      },
      skip: Platform.isWindows ? 'bash harness requires POSIX shell' : false,
    );

    test('fails cleanly for a reply without the strict bash format', () async {
      final workspace = await Directory.systemTemp.createTemp('minimal_agent_');
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });
      final harness = MinimalAgentHarness(
        provider: _ScriptedStreamingProvider(['Run ls']),
        harnessId: 'minimal-test',
      );

      final result = await harness.run(
        workspace: workspace,
        instruction: 'Inspect files.',
        modelId: 'fake',
        timeout: const Duration(seconds: 2),
      );

      expect(result.status, AgentRunStatus.failure);
      expect(result.metadata['terminal_reason'], 'malformed_reply');
      expect(result.stderrPreview, contains('fenced bash block'));
    });

    test(
      'terminates bash descendants after a timeout',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final harness = MinimalAgentHarness(
          provider: _ScriptedStreamingProvider([
            r'''```bash
(sleep 30) &
echo $! > child.pid
wait
```''',
          ]),
          harnessId: 'minimal-test',
        );

        final result = await harness.run(
          workspace: workspace,
          instruction: 'Wait.',
          modelId: 'fake',
          timeout: const Duration(milliseconds: 200),
        );

        expect(result.status, AgentRunStatus.timeout);
        final childPid = int.parse(
          (await File(
            p.join(workspace.path, 'child.pid'),
          ).readAsString()).trim(),
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
      'bounds command output',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final provider = _ScriptedStreamingProvider([
          '```bash\nprintf 1234567890\n```',
          'FINISH',
        ]);
        final harness = MinimalAgentHarness(
          provider: provider,
          harnessId: 'minimal-test',
          maxOutputChars: 4,
        );

        final result = await harness.run(
          workspace: workspace,
          instruction: 'Print output.',
          modelId: 'fake',
          timeout: const Duration(seconds: 2),
        );

        expect(result.status, AgentRunStatus.failure);
        expect(result.metadata['terminal_reason'], 'output_limit');
        expect(result.stdoutPreview, '7890');
        expect(result.metadata['output_truncated'], isTrue);
      },
      skip: Platform.isWindows ? 'bash harness requires POSIX shell' : false,
    );

    test('rejects adversarial replies outside the strict format', () async {
      for (final reply in [
        'I will FINISH after checking.',
        '```bash\ntrue\n```\n```bash\ntrue\n```',
        '```bash\n\n```',
      ]) {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final result =
            await MinimalAgentHarness(
              provider: _ScriptedStreamingProvider([reply]),
              harnessId: 'minimal-test',
            ).run(
              workspace: workspace,
              instruction: 'Do nothing.',
              modelId: 'fake',
              timeout: const Duration(seconds: 2),
            );

        expect(result.metadata['terminal_reason'], 'malformed_reply');
      }
    });

    test(
      'terminates output-flooding bash commands at the output limit',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'minimal_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final harness = MinimalAgentHarness(
          provider: _ScriptedStreamingProvider([
            '```bash\nwhile :; do printf 0123456789abcdef; done\n```',
          ]),
          harnessId: 'minimal-test',
          maxOutputChars: 128,
        );

        final result = await harness.run(
          workspace: workspace,
          instruction: 'Print output.',
          modelId: 'fake',
          timeout: const Duration(seconds: 5),
        );

        expect(result.status, AgentRunStatus.failure);
        expect(result.metadata['terminal_reason'], 'output_limit');
        expect(result.metadata['output_truncated'], isTrue);
        expect(result.latency, lessThan(const Duration(seconds: 2)));
      },
      skip: Platform.isWindows ? 'bash harness requires POSIX shell' : false,
      timeout: const Timeout(Duration(seconds: 8)),
    );

    test('records history truncation', () async {
      final workspace = await Directory.systemTemp.createTemp('minimal_agent_');
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });
      final result =
          await MinimalAgentHarness(
            provider: _ScriptedStreamingProvider([
              '```bash\nprintf output\n```',
              'FINISH',
            ]),
            harnessId: 'minimal-test',
            maxHistoryChars: 1,
          ).run(
            workspace: workspace,
            instruction: 'Print output.',
            modelId: 'fake',
            timeout: const Duration(seconds: 2),
          );

      expect(result.metadata['history_truncated'], isTrue);
    });
  });

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
        allowInternet: false,
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
      expect(sandbox.seenAllowInternet, isFalse);
      expect(sandbox.seenResourceLimits, isNull);
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      final expectedFactoryPaths = [
        for (final name in const [
          'settings.json',
          'auth.v2.file',
          'auth.v2.key',
        ])
          if (File(p.join(home, '.factory', name)).existsSync())
            p.join(home, '.factory', name),
      ];
      expect(sandbox.seenExtraReadOnlyPaths, expectedFactoryPaths);
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
      if (!await _skipUnlessBubblewrapAvailable()) return;
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

  group('CommandTemplateAgentHarness', () {
    test(
      'substitutes the template and lets the CLI edit the workspace',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'template_agent_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final script = await _writeExecutable(workspace, 'fake.sh', r'''
#!/bin/sh
printf '%s' "$1" > result.txt
''');
        final result =
            await CommandTemplateAgentHarness(
              providerId: 'fake-cli',
              config: CommandTemplateAgentConfig(
                name: 'fake-cli',
                executable: script.path,
                arguments: const ['{instruction}'],
                version: '1.2.3',
              ),
            ).run(
              workspace: workspace,
              instruction: 'edit this file',
              modelId: 'fake-model',
              timeout: const Duration(seconds: 2),
            );

        expect(result.succeeded, isTrue);
        expect(
          await File(p.join(workspace.path, 'result.txt')).readAsString(),
          'edit this file',
        );
        expect(result.metadata['agentHarness'], {
          'kind': 'command-template',
          'track': 'scaffold-dependent',
          'agent': 'fake-cli',
          'agentVersion': '1.2.3',
        });
      },
      skip: Platform.isWindows ? 'POSIX shell script test' : false,
    );

    test(
      'terminates a timed out CLI process tree',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'template_tree_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final script = await _writeExecutable(workspace, 'fake.sh', '''
#!/bin/sh
(sleep 30) &
echo \$! > child.pid
wait
''');
        final result = await _templateHarness(script).run(
          workspace: workspace,
          instruction: 'x',
          modelId: 'm',
          timeout: const Duration(milliseconds: 200),
        );

        expect(result.status, AgentRunStatus.timeout);
        final childPid = int.parse(
          File(p.join(workspace.path, 'child.pid')).readAsStringSync().trim(),
        );
        for (var i = 0; i < 20 && await _pidIsRunning(childPid); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(await _pidIsRunning(childPid), isFalse);
      },
      skip: Platform.isWindows ? 'POSIX process-tree assertion' : false,
    );

    test(
      'terminates output-flooding CLIs',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'template_flood_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final script = await _writeExecutable(workspace, 'fake.sh', '''
#!/bin/sh
while :; do printf '0123456789abcdef0123456789abcdef\\n'; done
''');
        final result =
            await CommandTemplateAgentHarness(
              providerId: 'fake-cli',
              config: CommandTemplateAgentConfig(
                name: 'fake',
                executable: script.path,
                arguments: const ['{instruction}'],
                version: 'test',
              ),
              maxProcessOutputChars: 128,
            ).run(
              workspace: workspace,
              instruction: 'x',
              modelId: 'm',
              timeout: const Duration(seconds: 5),
            );

        expect(result.status, AgentRunStatus.failure);
        expect(result.metadata['output_limit_exceeded'], isTrue);
      },
      skip: Platform.isWindows ? 'POSIX shell script test' : false,
    );

    test(
      'passes allowInternet to the generated-code sandbox',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'template_sandbox_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final script = await _writeExecutable(
          workspace,
          'fake.sh',
          '#!/bin/sh\n',
        );
        final sandbox = _RecordingGeneratedCodeSandbox();
        await _templateHarness(script, sandbox: sandbox).run(
          workspace: workspace,
          instruction: 'x',
          modelId: 'm',
          timeout: const Duration(seconds: 2),
          allowInternet: false,
        );
        expect(sandbox.seenAllowInternet, isFalse);
      },
      skip: Platform.isWindows ? 'POSIX shell script test' : false,
    );

    test(
      'redacts allowed credential values from CLI previews',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'template_redact_',
        );
        addTearDown(() async {
          if (await workspace.exists()) await workspace.delete(recursive: true);
        });
        final script = await _writeExecutable(
          workspace,
          'fake.sh',
          r'''#!/bin/sh
printf %s "$PATH"
''',
        );
        final result =
            await CommandTemplateAgentHarness(
              providerId: 'fake-cli',
              config: CommandTemplateAgentConfig(
                name: 'fake',
                executable: script.path,
                arguments: const ['{instruction}'],
                version: 'test',
              ),
              allowedSensitiveEnvironmentKeys: const ['PATH'],
            ).run(
              workspace: workspace,
              instruction: 'x',
              modelId: 'm',
              timeout: const Duration(seconds: 2),
            );

        expect(result.stdoutPreview, contains('[REDACTED:PATH]'));
        expect(
          result.stdoutPreview,
          isNot(contains(Platform.environment['PATH'])),
        );
      },
      skip: Platform.isWindows ? 'POSIX shell script test' : false,
    );

    test('resolves built-in command presets', () {
      final codex = CommandTemplateAgentConfig.preset(
        'codex',
        version: '1.0.0',
      );
      expect(codex.executable, 'codex');
      expect(codex.arguments, [
        'exec',
        '--sandbox',
        'workspace-write',
        '--model',
        '{model}',
        '{instruction}',
      ]);
      final claudeCode = CommandTemplateAgentConfig.preset(
        'claude-code',
        version: '1.0.0',
      );
      expect(claudeCode.executable, 'claude');
      expect(claudeCode.arguments, [
        '-p',
        '--permission-mode',
        'bypassPermissions',
        '--model',
        '{model}',
        '{instruction}',
      ]);
      final opencode = CommandTemplateAgentConfig.preset(
        'opencode',
        version: '1.0.0',
      );
      expect(opencode.executable, 'opencode');
      expect(opencode.arguments, [
        'run',
        '--auto',
        '--model',
        '{model}',
        '{instruction}',
      ]);
    });

    test('requires an instruction placeholder', () {
      expect(
        () => CommandTemplateAgentHarness(
          providerId: 'fake-cli',
          config: const CommandTemplateAgentConfig(
            name: 'fake',
            executable: 'fake',
            arguments: ['--model', '{model}'],
            version: '1.0.0',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unknown template placeholders', () {
      expect(
        () => CommandTemplateAgentHarness(
          providerId: 'fake-cli',
          config: const CommandTemplateAgentConfig(
            name: 'fake',
            executable: 'fake',
            arguments: ['{instruction}', '{work_dir}'],
            version: '1.0.0',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

CommandTemplateAgentHarness _templateHarness(
  File script, {
  GeneratedCodeSandbox? sandbox,
}) => CommandTemplateAgentHarness(
  providerId: 'fake-cli',
  config: CommandTemplateAgentConfig(
    name: 'fake',
    executable: script.path,
    arguments: const ['{instruction}'],
    version: 'test',
  ),
  generatedCodeSandbox: sandbox,
);

Future<File> _writeExecutable(
  Directory directory,
  String name,
  String body,
) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsString(body);
  final result = await Process.run('chmod', ['+x', file.path]);
  if (result.exitCode != 0) throw StateError('chmod failed');
  return file;
}

class _ScriptedStreamingProvider implements StreamingModelProvider {
  _ScriptedStreamingProvider(this.replies);

  final List<String> replies;
  final prompts = <String>[];
  var _index = 0;

  @override
  String get id => 'scripted';

  @override
  String get displayName => 'Scripted';

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => const [ModelInfo(id: 'fake')];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => throw UnimplementedError();

  @override
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async* {
    prompts.add(prompt);
    final reply = replies[_index++];
    yield const ModelStreamStarted();
    yield ModelStreamContentDelta(reply);
    yield const ModelStreamUsage(promptTokens: 2, completionTokens: 3);
    yield const ModelStreamCompleted();
  }

  @override
  void dispose() {}
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

Future<bool> _skipUnlessBubblewrapAvailable() async {
  try {
    await BubblewrapGeneratedCodeSandbox.ensureAvailable();
  } on Object catch (error) {
    markTestSkipped(error.toString());
    return false;
  }
  final probe = await Process.run('bwrap', const [
    '--ro-bind',
    '/',
    '/',
    '--unshare-pid',
    '--unshare-ipc',
    '--unshare-net',
    '/bin/true',
  ], runInShell: false);
  if (probe.exitCode != 0) {
    markTestSkipped(
      'bwrap functional probe failed with exit code ${probe.exitCode}',
    );
    return false;
  }
  return true;
}

String _shellSingleQuoted(String value) =>
    "'${value.replaceAll("'", "'\"'\"'")}'";

Future<bool> _pidIsRunning(int pid) async {
  final result = await Process.run('ps', ['-p', '$pid', '-o', 'stat=']);
  if (result.exitCode != 0) return false;
  final stat = result.stdout.toString().trim();
  return stat.isNotEmpty && !stat.startsWith('Z');
}
