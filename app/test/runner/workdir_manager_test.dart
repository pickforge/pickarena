import 'dart:io';

import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
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
      contains(safePathSegment('deepseek-v4-pro::high', prefix: 'model')),
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
    expect(partsB, contains(safePathSegment('openai/gpt-4o', prefix: 'model')));
    expect(partsB, isNot(contains('openai/gpt-4o')));

    root.deleteSync(recursive: true);
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
