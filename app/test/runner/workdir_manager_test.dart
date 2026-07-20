import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/patch_capture.dart';
import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'createTaskWorkdir writes fixtures and splices generated code',
    () async {
      final root = await Directory.systemTemp.createTemp('dart_arena_root_');
      final mgr = WorkdirManager(root: root);

      final dir = await mgr.createTaskWorkdir(
        runId: 'r1',
        providerId: 'ollama_local',
        modelId: 'm',
        taskId: 't',
        fixtures: const {
          'pubspec.yaml': 'name: tmp\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n',
          'lib/pagination.dart': '// broken',
        },
        generatedCode: 'int answer() => 42;\n',
        generatedCodePath: 'lib/pagination.dart',
      );

      expect(File(p.join(dir.path, 'pubspec.yaml')).existsSync(), isTrue);
      expect(
        File(p.join(dir.path, 'lib', 'pagination.dart')).readAsStringSync(),
        'int answer() => 42;\n',
      );

      root.deleteSync(recursive: true);
    },
  );

  test('createTaskWorkdir recreates clean generated-code workspace', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_codegen_clean_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final mgr = WorkdirManager(root: root);

    final first = await mgr.createTaskWorkdir(
      runId: 'r1',
      providerId: 'provider',
      modelId: 'model',
      taskId: 'task',
      fixtures: const {
        'pubspec.yaml': 'name: tmp\n',
        'lib/answer.dart': 'String answer() => "fixture";\n',
      },
      generatedCode: 'String answer() => "one";\n',
      generatedCodePath: 'lib/answer.dart',
    );
    await File(p.join(first.path, 'lib', 'stale.dart')).writeAsString('stale');
    await File(
      p.join(first.path, 'test', '_hidden', 'leaked_test.dart'),
    ).create(recursive: true);

    final second = await mgr.createTaskWorkdir(
      runId: 'r1',
      providerId: 'provider',
      modelId: 'model',
      taskId: 'task',
      fixtures: const {
        'pubspec.yaml': 'name: tmp\n',
        'lib/answer.dart': 'String answer() => "fixture";\n',
      },
      generatedCode: 'String answer() => "two";\n',
      generatedCodePath: 'lib/answer.dart',
    );

    expect(second.path, first.path);
    expect(
      File(p.join(second.path, 'lib', 'answer.dart')).readAsStringSync(),
      'String answer() => "two";\n',
    );
    expect(
      File(p.join(second.path, 'lib', 'stale.dart')).existsSync(),
      isFalse,
    );
    expect(
      File(
        p.join(second.path, 'test', '_hidden', 'leaked_test.dart'),
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'collectWorkspaceIsolationEvidence redacts paths and contents',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_isolation_evidence_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'runs', 'r', 'p', 'm', 't'));
      await workDir.create(recursive: true);
      await File(
        p.join(workDir.path, 'lib', 'visible.dart'),
      ).create(recursive: true);
      await File(
        p.join(workDir.path, 'lib', 'visible.dart'),
      ).writeAsString('visible contents');
      await File(
        p.join(workDir.path, 'test', '_hidden', 'secret_test.dart'),
      ).create(recursive: true);
      await File(
        p.join(workDir.path, 'test', '_hidden', 'secret_test.dart'),
      ).writeAsString('hidden verifier contents');

      final evidence = await WorkdirManager(
        root: root,
      ).collectWorkspaceIsolationEvidence(workDir);
      final evidenceJson = jsonEncode(evidence.toJson());

      expect(evidence.workdirUnderRunsRoot, isTrue);
      expect(evidence.rootConfined, isTrue);
      expect(evidence.relativePathsOnly, isTrue);
      expect(evidence.restrictedPathCount, greaterThan(0));
      expect(evidence.restrictedPathsAbsent, isFalse);
      expect(evidence.visibleFileCount, 1);
      expect(evidence.visibleManifestSha256, hasLength(64));
      expect(evidenceJson, isNot(contains(root.path)));
      expect(evidenceJson, isNot(contains(workDir.path)));
      expect(evidenceJson, isNot(contains('visible.dart')));
      expect(evidenceJson, isNot(contains('secret_test.dart')));
      expect(evidenceJson, isNot(contains('visible contents')));
      expect(evidenceJson, isNot(contains('hidden verifier contents')));
    },
  );

  test(
    'agent workspace isolation ignores benchmark infrastructure only',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agent_isolation_evidence_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'runs', 'r', 'p', 'm', 't'));
      await File(
        p.join(workDir.path, 'lib', 'visible.dart'),
      ).create(recursive: true);
      await File(
        p.join(workDir.path, 'lib', 'visible.dart'),
      ).writeAsString('visible');
      await File(p.join(workDir.path, '.git', 'index')).create(recursive: true);
      await File(p.join(workDir.path, '.git', 'index')).writeAsString('git');
      await File(
        p.join(workDir.path, '.dart_tool', 'package_config.json'),
      ).create(recursive: true);
      await File(
        p.join(workDir.path, '.dart_tool', 'package_config.json'),
      ).writeAsString('{}');

      final manager = WorkdirManager(root: root);
      final evidence = await manager.collectWorkspaceIsolationEvidence(
        workDir,
        ignoreBenchmarkInfrastructure: true,
      );

      expect(evidence.restrictedPathsAbsent, isTrue);
      expect(evidence.restrictedPathCount, 0);
      expect(evidence.visibleFileCount, 1);

      await File(
        p.join(workDir.path, 'reference', 'answer.dart'),
      ).create(recursive: true);
      final leakedEvidence = await manager.collectWorkspaceIsolationEvidence(
        workDir,
        ignoreBenchmarkInfrastructure: true,
      );
      expect(leakedEvidence.restrictedPathsAbsent, isFalse);
      expect(leakedEvidence.restrictedPathCount, greaterThan(0));

      await Directory(
        p.join(workDir.path, 'reference'),
      ).delete(recursive: true);
      await File(
        p.join(workDir.path, 'lib', 'build', 'reference', 'answer.dart'),
      ).create(recursive: true);
      final nestedLeakEvidence = await manager
          .collectWorkspaceIsolationEvidence(
            workDir,
            ignoreBenchmarkInfrastructure: true,
          );
      expect(nestedLeakEvidence.restrictedPathsAbsent, isFalse);
      expect(nestedLeakEvidence.restrictedPathCount, greaterThan(0));
    },
  );

  test(
    'agent workspace isolation skips only infrastructure symlinks',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agent_isolation_symlink_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'runs', 'r', 'p', 'm', 't'));
      await workDir.create(recursive: true);
      final target = File(p.join(workDir.path, 'target.txt'));
      await target.writeAsString('target');
      await Link(
        p.join(workDir.path, '.dart_tool', 'cache-link'),
      ).create(target.path, recursive: true);

      final manager = WorkdirManager(root: root);
      final infrastructureOnly = await manager
          .collectWorkspaceIsolationEvidence(
            workDir,
            ignoreBenchmarkInfrastructure: true,
          );
      expect(infrastructureOnly.symlinkCount, 0);
      expect(infrastructureOnly.restrictedPathCount, 0);

      await Link(
        p.join(workDir.path, 'lib', 'visible-link'),
      ).create(target.path, recursive: true);
      final withVisibleLink = await manager.collectWorkspaceIsolationEvidence(
        workDir,
        ignoreBenchmarkInfrastructure: true,
      );
      expect(withVisibleLink.symlinkCount, 1);
      expect(withVisibleLink.restrictedPathCount, 0);

      await Link(
        p.join(workDir.path, 'build', '_hidden'),
      ).create(target.path, recursive: true);
      final withRestrictedInfrastructureLink = await manager
          .collectWorkspaceIsolationEvidence(
            workDir,
            ignoreBenchmarkInfrastructure: true,
          );
      expect(withRestrictedInfrastructureLink.symlinkCount, 1);
      expect(withRestrictedInfrastructureLink.restrictedPathCount, 1);
      expect(withRestrictedInfrastructureLink.restrictedPathsAbsent, isFalse);
    },
    skip: Platform.isWindows ? 'POSIX symlink test' : false,
  );

  test('uses safe modelId path segments', () async {
    final root = await Directory.systemTemp.createTemp('dart_arena_sanitize_');
    final mgr = WorkdirManager(root: root);

    final dirA = await mgr.createTaskWorkdir(
      runId: 'r1',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro::high',
      taskId: 't',
      fixtures: const {},
      generatedCode: null,
      generatedCodePath: 'lib/a.dart',
    );
    expect(dirA.existsSync(), isTrue);
    final partsA = p.split(dirA.path);
    expect(
      partsA,
      contains(
        safePathSegment(
          'deepseek-v4-pro::high',
          prefix: 'model',
          maxStemChars: 8,
        ),
      ),
    );
    expect(partsA, isNot(contains('deepseek-v4-pro::high')));

    final dirB = await mgr.createTaskWorkdir(
      runId: 'r1',
      providerId: 'openrouter',
      modelId: 'openai/gpt-4o',
      taskId: 't',
      fixtures: const {},
      generatedCode: null,
      generatedCodePath: 'lib/a.dart',
    );
    expect(dirB.existsSync(), isTrue);
    final partsB = p.split(dirB.path);
    expect(
      partsB,
      contains(
        safePathSegment('openai/gpt-4o', prefix: 'model', maxStemChars: 8),
      ),
    );
    expect(partsB, isNot(contains('openai/gpt-4o')));

    root.deleteSync(recursive: true);
  });

  test('keeps long agentic workdir segments compact', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_agentic_long_path_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final dir = await WorkdirManager(root: root).createAgenticTaskWorkdir(
      runId: 'spark-official-smoke-20260604-with-extra-release-context',
      providerId: 'droid',
      modelId: 'custom:gpt-5.3-codex-spark---Codex',
      taskId: 'navigation.auth_redirect_race',
      workspace: const TaskWorkspace(files: {'lib/answer.dart': 'answer'}),
    );

    final relative = p.relative(dir.path, from: root.path);
    for (final segment in p.split(relative)) {
      expect(segment.length, lessThanOrEqualTo(32));
    }
    expect(relative.length, lessThan(130));
  });

  test(
    'rejects workspace path traversal for fixtures and generated files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_traversal_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final mgr = WorkdirManager(root: root);

      await expectLater(
        mgr.createTaskWorkdir(
          runId: '../run',
          providerId: '../provider',
          modelId: '../model',
          taskId: '../task',
          fixtures: const {'../secret.txt': 'secret'},
          generatedCode: null,
          generatedCodePath: 'lib/a.dart',
        ),
        throwsArgumentError,
      );

      await expectLater(
        mgr.createTaskWorkdir(
          runId: '../run',
          providerId: '../provider',
          modelId: '../model',
          taskId: '../task',
          fixtures: const {},
          generatedCode: 'secret',
          generatedCodePath: '../secret.txt',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'createAgenticTaskWorkdir copies visible files and excludes secrets',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'dart_arena_fixture_',
      );
      final root = await Directory.systemTemp.createTemp('dart_arena_agentic_');
      addTearDown(() async {
        if (await fixtureRoot.exists()) {
          await fixtureRoot.delete(recursive: true);
        }
        if (await root.exists()) await root.delete(recursive: true);
      });

      await File(p.join(fixtureRoot.path, 'pubspec.yaml')).writeAsString('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
      await File(
        p.join(fixtureRoot.path, 'lib', 'visible.dart'),
      ).create(recursive: true);
      await File(
        p.join(fixtureRoot.path, 'lib', 'visible.dart'),
      ).writeAsString('visible');
      await File(
        p.join(fixtureRoot.path, 'test', '_hidden', 'secret_test.dart'),
      ).create(recursive: true);
      await File(
        p.join(fixtureRoot.path, 'test', '_hidden', 'secret_test.dart'),
      ).writeAsString('secret');
      await File(
        p.join(fixtureRoot.path, 'reference', 'solution.dart'),
      ).create(recursive: true);
      await File(
        p.join(fixtureRoot.path, 'reference', 'solution.dart'),
      ).writeAsString('solution');

      final dir = await WorkdirManager(root: root).createAgenticTaskWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: TaskWorkspace(fixtureRootPath: fixtureRoot.path),
      );

      expect(
        File(p.join(dir.path, 'lib', 'visible.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(dir.path, 'test', '_hidden', 'secret_test.dart'),
        ).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(dir.path, 'reference', 'solution.dart')).existsSync(),
        isFalse,
      );
      expect(Directory(p.join(dir.path, '.git')).existsSync(), isTrue);
    },
  );

  test(
    'createAgenticTaskWorkdir rejects absolute and escaping file paths',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_path_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final manager = WorkdirManager(root: root);
      await expectLater(
        manager.createAgenticTaskWorkdir(
          runId: 'r',
          providerId: 'p',
          modelId: 'm',
          taskId: 'abs',
          workspace: TaskWorkspace(files: {p.join(root.path, 'x.dart'): 'x'}),
        ),
        throwsArgumentError,
      );
      await expectLater(
        manager.createAgenticTaskWorkdir(
          runId: 'r',
          providerId: 'p',
          modelId: 'm',
          taskId: 'escape',
          workspace: const TaskWorkspace(files: {'../outside.dart': 'x'}),
        ),
        throwsArgumentError,
      );
    },
  );

  test('createAgenticTaskWorkdir excludes explicit hidden assets', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_agentic_explicit_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final dir = await WorkdirManager(root: root).createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      workspace: const TaskWorkspace(
        files: {
          'lib/visible.dart': 'visible',
          'test/_hidden/secret_test.dart': 'secret',
          'reference/lib/solution.dart': 'solution',
          'author_notes.md': 'notes',
          'task_qa/report.md': 'qa',
        },
      ),
    );

    expect(File(p.join(dir.path, 'lib', 'visible.dart')).existsSync(), isTrue);
    expect(
      File(
        p.join(dir.path, 'test', '_hidden', 'secret_test.dart'),
      ).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(dir.path, 'reference', 'lib', 'solution.dart')).existsSync(),
      isFalse,
    );
    expect(File(p.join(dir.path, 'author_notes.md')).existsSync(), isFalse);
    expect(
      File(p.join(dir.path, 'task_qa', 'report.md')).existsSync(),
      isFalse,
    );
  });

  test(
    'replays captured patches into a clean agentic grading workdir',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_grading_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      const workspace = TaskWorkspace(
        files: {
          'lib/answer.dart': 'int answer() => 41;\n',
          'test/_hidden/answer_hidden_test.dart': 'hidden',
        },
      );
      final manager = WorkdirManager(root: root);
      final agentWorkspace = await manager.createAgenticTaskWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: workspace,
      );
      await File(
        p.join(agentWorkspace.path, 'lib', 'answer.dart'),
      ).writeAsString('int answer() => 42;\n');
      final capturedPatch = await const PatchCapture().capture(agentWorkspace);

      final gradingWorkspace = await manager.createAgenticGradingWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: workspace,
      );

      expect(p.basename(gradingWorkspace.path), 'trial_0_grading');
      expect(p.isWithin(agentWorkspace.path, gradingWorkspace.path), isFalse);
      expect(
        await File(
          p.join(gradingWorkspace.path, 'lib', 'answer.dart'),
        ).readAsString(),
        'int answer() => 41;\n',
      );
      expect(
        await File(
          p.join(
            gradingWorkspace.path,
            'test',
            '_hidden',
            'answer_hidden_test.dart',
          ),
        ).exists(),
        isFalse,
      );

      await manager.applyCapturedPatch(gradingWorkspace, capturedPatch.patch);

      expect(
        await File(
          p.join(gradingWorkspace.path, 'lib', 'answer.dart'),
        ).readAsString(),
        'int answer() => 42;\n',
      );
    },
  );

  test('strips restricted paths reintroduced by a captured patch', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_grading_strip_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    const workspace = TaskWorkspace(
      files: {'lib/answer.dart': 'int answer() => 41;\n'},
    );
    final manager = WorkdirManager(root: root);
    final agentWorkspace = await manager.createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      workspace: workspace,
    );
    await File(
      p.join(agentWorkspace.path, 'test', '_hidden', 'leaked_test.dart'),
    ).create(recursive: true);
    await File(
      p.join(agentWorkspace.path, 'test', '_hidden', 'leaked_test.dart'),
    ).writeAsString('leaked');
    final capturedPatch = await const PatchCapture().capture(agentWorkspace);
    expect(capturedPatch.patch, contains('_hidden/leaked_test.dart'));

    final gradingWorkspace = await manager.createAgenticGradingWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      workspace: workspace,
    );
    await manager.applyCapturedPatch(gradingWorkspace, capturedPatch.patch);

    expect(
      await File(
        p.join(gradingWorkspace.path, 'test', '_hidden', 'leaked_test.dart'),
      ).exists(),
      isFalse,
    );
  });

  test(
    'removes symlinks a captured patch would reintroduce into grading',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_grading_symlink_',
      );
      final outside = await Directory.systemTemp.createTemp(
        'dart_arena_symlink_target_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      await File(p.join(outside.path, 'secret.txt')).writeAsString('secret');
      const workspace = TaskWorkspace(
        files: {'lib/answer.dart': 'int answer() => 41;\n'},
      );
      final manager = WorkdirManager(root: root);
      final agentWorkspace = await manager.createAgenticTaskWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: workspace,
      );
      await Link(
        p.join(agentWorkspace.path, 'lib', 'leak.txt'),
      ).create(p.join(outside.path, 'secret.txt'));
      final capturedPatch = await const PatchCapture().capture(agentWorkspace);
      expect(capturedPatch.patch, contains('lib/leak.txt'));

      final gradingWorkspace = await manager.createAgenticGradingWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: workspace,
      );
      await manager.applyCapturedPatch(gradingWorkspace, capturedPatch.patch);

      expect(
        await Link(p.join(gradingWorkspace.path, 'lib', 'leak.txt')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(gradingWorkspace.path, 'lib', 'leak.txt')).exists(),
        isFalse,
      );
    },
  );

  test(
    'captures against the recorded baseline even after the tag is retargeted',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_baseline_sha_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      const workspace = TaskWorkspace(
        files: {'lib/answer.dart': 'int answer() => 41;\n'},
      );
      final manager = WorkdirManager(root: root);
      final agentWorkspace = await manager.createAgenticTaskWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: workspace,
      );
      final baselineSha = await manager.resetPatchBaseline(agentWorkspace);
      expect(baselineSha, matches(RegExp(r'^[0-9a-f]{40}$')));

      await File(
        p.join(agentWorkspace.path, 'lib', 'answer.dart'),
      ).writeAsString('int answer() => 42;\n');
      Future<void> git(List<String> args) async {
        final result = await Process.run(
          'git',
          args,
          workingDirectory: agentWorkspace.path,
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }

      await git(['add', '.']);
      await git(['commit', '-m', 'agent solution']);
      await git(['tag', '-f', 'arena_baseline']);

      final captured = await const PatchCapture().capture(
        agentWorkspace,
        baselineRef: baselineSha,
      );
      expect(captured.patch, contains('+int answer() => 42;'));
    },
  );

  test(
    'createAgenticTaskWorkdir does not follow fixture symlinks',
    () async {
      final fixtureRoot = await Directory.systemTemp.createTemp(
        'dart_arena_fixture_symlink_',
      );
      final outside = await Directory.systemTemp.createTemp(
        'dart_arena_outside_secret_',
      );
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_symlink_',
      );
      addTearDown(() async {
        if (await fixtureRoot.exists()) {
          await fixtureRoot.delete(recursive: true);
        }
        if (await outside.exists()) await outside.delete(recursive: true);
        if (await root.exists()) await root.delete(recursive: true);
      });

      await File(
        p.join(fixtureRoot.path, 'lib', 'visible.dart'),
      ).create(recursive: true);
      await File(
        p.join(fixtureRoot.path, 'lib', 'visible.dart'),
      ).writeAsString('visible');
      await File(p.join(outside.path, 'secret.dart')).writeAsString('secret');
      await Link(
        p.join(fixtureRoot.path, 'lib', 'secret_link.dart'),
      ).create(p.join(outside.path, 'secret.dart'));

      final dir = await WorkdirManager(root: root).createAgenticTaskWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        workspace: TaskWorkspace(fixtureRootPath: fixtureRoot.path),
      );

      expect(
        File(p.join(dir.path, 'lib', 'visible.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(dir.path, 'lib', 'secret_link.dart')).existsSync(),
        isFalse,
      );
    },
    skip: Platform.isWindows ? 'POSIX symlink test' : false,
  );

  test(
    'createAgenticTaskWorkdir scrubs baseline git process environment',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_git_env_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final gitLog = File(p.join(root.path, 'git_env.log'));
      final fakeGit = await _writeFakeGitExecutable(root, gitLog);

      final dir =
          await WorkdirManager(
            root: root,
            gitExecutable: fakeGit.path,
            deniedEnvironmentKeys: const ['HOME'],
          ).createAgenticTaskWorkdir(
            runId: 'r',
            providerId: 'p',
            modelId: 'm',
            taskId: 't',
            workspace: const TaskWorkspace(
              files: {'lib/answer.dart': 'answer'},
            ),
          );

      expect(Directory(p.join(dir.path, '.git')).existsSync(), isTrue);
      final log = await gitLog.readAsString();
      expect(log, contains('ARGS:init'));
      expect(
        log,
        contains('ARGS:config user.email dart-arena@example.invalid'),
      );
      expect(log, contains('ARGS:add .'));
      expect(log, isNot(contains('\nHOME=')));
      expect(log, isNot(contains('\nXDG_CONFIG_HOME=')));
      expect(log, isNot(contains('\nXDG_CONFIG_DIRS=')));
      expect(log, contains('\nGIT_CONFIG_NOSYSTEM=1'));
      expect(log, contains('\nGIT_TERMINAL_PROMPT=0'));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'createAgenticTaskWorkdir kills hanging baseline git process',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_git_timeout_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final marker = File(p.join(root.path, 'git_marker.log'));
      final fakeGit = await _writeHangingGitExecutable(root, marker);

      final manager = WorkdirManager(
        root: root,
        gitExecutable: fakeGit.path,
        gitTimeout: const Duration(milliseconds: 120),
      );
      final stopwatch = Stopwatch()..start();

      await expectLater(
        manager.createAgenticTaskWorkdir(
          runId: 'r',
          providerId: 'p',
          modelId: 'm',
          taskId: 't',
          workspace: const TaskWorkspace(files: {'lib/answer.dart': 'answer'}),
        ),
        throwsA(isA<TimeoutException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final log = await marker.readAsString();
      expect(log, contains('ARGS:init'));
      expect(log, contains('started'));
      expect(log, isNot(contains('done')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'createAgenticTaskWorkdir fails fast when baseline git output floods',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_git_output_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final fakeGit = await _writeChattyGitExecutable(root);

      final manager = WorkdirManager(
        root: root,
        gitExecutable: fakeGit.path,
        gitTimeout: const Duration(seconds: 5),
        gitMaxOutputChars: 32,
      );

      await expectLater(
        manager.createAgenticTaskWorkdir(
          runId: 'r',
          providerId: 'p',
          modelId: 'm',
          taskId: 't',
          workspace: const TaskWorkspace(files: {'lib/answer.dart': 'answer'}),
        ),
        throwsA(
          isA<ProcessException>().having(
            (e) => e.message,
            'message',
            contains('baseline git output exceeded 32 characters'),
          ),
        ),
      );
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('createAgenticTaskWorkdir recreates clean trial workspace', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_agentic_clean_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final manager = WorkdirManager(root: root);
    final first = await manager.createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      trialIndex: 1,
      workspace: const TaskWorkspace(files: {'lib/answer.dart': 'one'}),
    );
    await File(p.join(first.path, 'lib', 'stale.dart')).writeAsString('stale');

    final second = await manager.createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      trialIndex: 1,
      workspace: const TaskWorkspace(files: {'lib/answer.dart': 'two'}),
    );

    expect(second.path, first.path);
    expect(
      File(p.join(second.path, 'lib', 'answer.dart')).readAsStringSync(),
      'two',
    );
    expect(
      File(p.join(second.path, 'lib', 'stale.dart')).existsSync(),
      isFalse,
    );

    final status = await Process.run('git', [
      'status',
      '--porcelain',
    ], workingDirectory: second.path);
    expect(status.exitCode, 0);
    expect(status.stdout.toString(), isEmpty);
  });

  test('createAgenticTaskWorkdir keeps trials isolated as siblings', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_agentic_trials_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final manager = WorkdirManager(root: root);
    final trial0 = await manager.createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 'task/with/slash',
      trialIndex: 0,
      workspace: const TaskWorkspace(files: {'lib/answer.dart': 'zero'}),
    );
    final trial1 = await manager.createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 'task/with/slash',
      trialIndex: 1,
      workspace: const TaskWorkspace(files: {'lib/answer.dart': 'one'}),
    );

    await File(
      p.join(trial1.path, 'lib', 'trial_one_marker.dart'),
    ).writeAsString('keep');
    await manager.createAgenticTaskWorkdir(
      runId: 'r',
      providerId: 'p',
      modelId: 'm',
      taskId: 'task/with/slash',
      trialIndex: 0,
      workspace: const TaskWorkspace(files: {'lib/answer.dart': 'zero again'}),
    );

    expect(p.dirname(trial0.path), p.dirname(trial1.path));
    expect(trial0.path, isNot(trial1.path));
    expect(
      File(p.join(trial1.path, 'lib', 'trial_one_marker.dart')).existsSync(),
      isTrue,
    );
  });
}

Future<File> _writeFakeGitExecutable(Directory root, File log) async {
  final script = File(p.join(root.path, 'fake_git.sh'));
  await script.writeAsString('''
#!/bin/sh
printf 'ARGS:%s\\n' "\$*" >> '${log.path}'
/usr/bin/env >> '${log.path}'
printf '%s\\n' '---' >> '${log.path}'
if [ "\$1" = "init" ]; then
  /bin/mkdir -p .git
fi
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeHangingGitExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_git_hang.sh'));
  await script.writeAsString('''
#!/bin/sh
printf 'ARGS:%s\\n' "\$*" >> '${marker.path}'
if [ "\$1" = "init" ]; then
  /bin/mkdir -p .git
fi
echo started >> '${marker.path}'
sleep 20 && echo done >> '${marker.path}'
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeChattyGitExecutable(Directory root) async {
  final script = File(p.join(root.path, 'fake_git_chatty.sh'));
  await script.writeAsString('''
#!/bin/sh
if [ "\$1" = "init" ]; then
  /bin/mkdir -p .git
fi
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
