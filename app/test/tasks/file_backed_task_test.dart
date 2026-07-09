import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/runner/task_qa_runner.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('loads a DeepSWE-style task bundle without private leakage', () async {
    final root = await Directory.systemTemp.createTemp('file_backed_task_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bundle = await _writeBundle(root);

    final tasks = await loadFileBackedTasks(root);
    expect(tasks, hasLength(1));
    final task = tasks.single;
    expect(task.bundleDirectory.path, bundle.path);
    expect(task.id, 'file.answer_fix');
    expect(task.version, 2);
    expect(task.category.name, 'bugFix');
    expect(task.track, BenchmarkTrack.codegen);
    expect(task.tags.map((tag) => tag.slug), contains('bugfix'));
    expect(task.difficulty, TaskDifficulty.easy);
    expect(task.platformRequirements.map((platform) => platform.name), [
      'linux',
    ]);
    expect(task.releaseMetadata.toJson(), {
      'corpus': 'public_diagnostic',
      'status': 'active',
    });
    expect(task.allowInternet, isFalse);
    expect(task.resourceLimits.toJson(), {
      'cpus': 2,
      'memoryMb': 8192,
      'maxProcesses': 64,
      'maxOutputBytes': 1048576,
    });

    await task.ensureLoaded();
    expect(task.prompt, contains('return 42'));
    expect(
      task.fixtures.keys,
      unorderedEquals([
        'lib/answer.dart',
        'pubspec.yaml',
        'test/answer_test.dart',
      ]),
    );
    expect(
      task.fixtures.keys,
      isNot(contains('test/_hidden/answer_test.dart')),
    );
    expect(
      task.hiddenVerifiers.single.testPath,
      'test/_hidden/answer_test.dart',
    );
    expect(task.hiddenVerifiers.single.id, 'answer_hidden');
    expect(task.hiddenVerifiers.single.authoredId, 'answer_hidden');
    expect(task.referenceSolution, isNotNull);
    expect(
      (task.referenceSolution! as ReferenceFileSolution).rootPath,
      'solution',
    );
    expect(task.negativeCases.map((negative) => negative.kind), {
      TaskNegativeCaseKind.noop,
      TaskNegativeCaseKind.apiBreaking,
    });
    expect(task.negativeCases.map((negative) => negative.rootPath), {
      'negative_cases/noop',
      'negative_cases/api_breaking',
    });
  });

  test('normalizes custom hidden verifier IDs for classification', () async {
    final root = await Directory.systemTemp.createTemp(
      'file_backed_hidden_id_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    await _writeBundle(root, hiddenVerifierId: 'edge_cases');

    final task = (await loadFileBackedTasks(root)).single;
    await task.ensureLoaded();

    expect(task.hiddenVerifiers.single.id, 'edge_cases_hidden');
    expect(task.hiddenVerifiers.single.authoredId, 'edge_cases');
  });

  test('rejects path-unsafe task IDs and generated code paths', () async {
    final root = await Directory.systemTemp.createTemp('file_backed_unsafe_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final badId = await _writeBundle(root, id: '../bad');
    await expectLater(FileBackedTask.load(badId), throwsArgumentError);

    final badPath = await _writeBundle(
      root,
      directoryName: 'bad_generated_path',
      generatedCodePath: '../lib/answer.dart',
    );
    await expectLater(FileBackedTask.load(badPath), throwsArgumentError);
  });

  test('rejects invalid network and resource policy fields', () async {
    final root = await Directory.systemTemp.createTemp('file_backed_policy_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final badNetwork = await _writeBundle(
      root,
      directoryName: 'bad_network',
      policyYaml: 'network: sometimes\n',
    );
    await expectLater(FileBackedTask.load(badNetwork), throwsFormatException);

    final badResources = await _writeBundle(
      root,
      directoryName: 'bad_resources',
      policyYaml: '''
network: false
resources:
  cpus: 0
''',
    );
    await expectLater(FileBackedTask.load(badResources), throwsFormatException);
  });

  test('rejects invalid release metadata fields', () async {
    final root = await Directory.systemTemp.createTemp('file_backed_release_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final badRelease = await _writeBundle(
      root,
      directoryName: 'bad_release',
      releaseYaml: '''
release:
  corpus: maybe_official
  status: active
''',
    );

    await expectLater(FileBackedTask.load(badRelease), throwsFormatException);
  });

  test(
    'rejects symlinked bundle instruction and workspace files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'file_backed_symlink_',
      );
      final outside = await Directory.systemTemp.createTemp(
        'file_backed_outside_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      final secret = File(p.join(outside.path, 'secret.txt'));
      await secret.writeAsString('secret');
      final externalManifest = File(p.join(outside.path, 'task.yaml'));
      await externalManifest.writeAsString('id: external\n');

      final manifestBundle = await _writeBundle(
        root,
        directoryName: 'manifest_link',
      );
      await File(p.join(manifestBundle.path, 'task.yaml')).delete();
      await Link(
        p.join(manifestBundle.path, 'task.yaml'),
      ).create(externalManifest.path);
      await expectLater(
        FileBackedTask.load(manifestBundle),
        throwsArgumentError,
      );

      final instructionBundle = await _writeBundle(
        root,
        directoryName: 'instruction_link',
      );
      await File(p.join(instructionBundle.path, 'instruction.md')).delete();
      await Link(
        p.join(instructionBundle.path, 'instruction.md'),
      ).create(secret.path);
      final instructionTask = await FileBackedTask.load(instructionBundle);
      await expectLater(instructionTask.ensureLoaded(), throwsArgumentError);

      final workspaceBundle = await _writeBundle(
        root,
        directoryName: 'workspace_link',
      );
      await File(
        p.join(workspaceBundle.path, 'baseline/lib/answer.dart'),
      ).delete();
      await Link(
        p.join(workspaceBundle.path, 'baseline/lib/answer.dart'),
      ).create(secret.path);
      final workspaceTask = await FileBackedTask.load(workspaceBundle);
      await expectLater(workspaceTask.ensureLoaded(), throwsArgumentError);

      final workspaceRootBundle = await _writeBundle(
        root,
        directoryName: 'workspace_root_link',
      );
      await Directory(
        p.join(workspaceRootBundle.path, 'baseline'),
      ).delete(recursive: true);
      await Directory(
        p.join(outside.path, 'baseline/lib'),
      ).create(recursive: true);
      await File(
        p.join(outside.path, 'baseline/lib/answer.dart'),
      ).writeAsString('secret');
      await Link(
        p.join(workspaceRootBundle.path, 'baseline'),
      ).create(p.join(outside.path, 'baseline'));
      final workspaceRootTask = await FileBackedTask.load(workspaceRootBundle);
      await expectLater(workspaceRootTask.ensureLoaded(), throwsArgumentError);
    },
    skip: Platform.isWindows ? 'POSIX symlink test' : false,
  );

  test(
    'file-backed bundle participates in task QA',
    () async {
      final root = await Directory.systemTemp.createTemp('file_backed_qa_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      await _writeBundle(Directory(p.join(root.path, 'bundles')));
      final task = (await loadFileBackedTasks(
        Directory(p.join(root.path, 'bundles')),
      )).single;

      final report = await TaskQaRunner(
        workdirManager: WorkdirManager(
          root: Directory(p.join(root.path, 'workdirs')),
        ),
        requiredHiddenFlakeRuns: 1,
        requireNegativeCases: true,
      ).run(task);

      final failures = report.failureMessages.join('\n');
      expect(report.baselineHiddenFailed, isTrue, reason: failures);
      expect(report.referencePassed, isTrue, reason: failures);
      expect(report.negativeCasesRejected, isTrue, reason: failures);
      expect(report.requiredNegativeCaseKindsCovered, isTrue, reason: failures);
      expect(report.promptSafety.passed, isTrue, reason: failures);
      expect(report.failureMessages, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'file-backed bundle fails task QA when instruction leaks hidden test filename',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'file_backed_prompt_leak_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      await _writeBundle(
        Directory(p.join(root.path, 'bundles')),
        hiddenTestPath: 'test/_hidden/answer_hidden_test.dart',
        instruction:
            'Make answer() return 42. The hidden verifier is answer_hidden_test.dart.\n',
      );
      final task = (await loadFileBackedTasks(
        Directory(p.join(root.path, 'bundles')),
      )).single;

      final report = await TaskQaRunner(
        workdirManager: WorkdirManager(
          root: Directory(p.join(root.path, 'workdirs')),
        ),
        requiredHiddenFlakeRuns: 1,
        requireNegativeCases: true,
      ).run(task);

      expect(report.promptSafety.hiddenVerifierLeakFree, isFalse);
      expect(report.promptSafety.passed, isFalse);
      expect(
        report.failureMessages,
        contains(
          'Task prompt or prompt-safe context leaks hidden verifier content.',
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<Directory> _writeBundle(
  Directory root, {
  String directoryName = 'answer_fix',
  String id = 'file.answer_fix',
  String generatedCodePath = 'lib/answer.dart',
  String hiddenVerifierId = 'answer_hidden',
  String hiddenTestPath = 'test/_hidden/answer_test.dart',
  String instruction = 'Make answer() return 42.\n',
  String releaseYaml = '',
  String policyYaml = '''
network: false
resources:
  cpus: 2
  memory_mb: 8192
  max_processes: 64
  max_output_bytes: 1048576
''',
}) async {
  final bundle = Directory(p.join(root.path, directoryName));
  await _writeFile(bundle, 'task.yaml', '''
schemaVersion: 1
id: $id
version: 2
category: bug_fix
track: codegen
tags:
  - bugfix
difficulty: easy
platformRequirements:
  - linux
timeoutSeconds: 60
$releaseYaml
$policyYaml
generatedCodePath: $generatedCodePath
isFlutter: false
instructionPath: instruction.md
workspace:
  root: baseline
  files:
    pubspec.yaml: pubspec.yaml
    lib/answer.dart: lib/answer.dart
    test/answer_test.dart: test/answer_test.dart
hiddenVerifiers:
  - id: $hiddenVerifierId
    testPath: $hiddenTestPath
    root: hidden_tests
    files:
      $hiddenTestPath: $hiddenTestPath
reference:
  type: files
  root: solution
  files:
    lib/answer.dart: lib/answer.dart
negativeCases:
  - id: noop
    kind: noop
    description: Leaves the original answer unchanged.
    root: negative_cases/noop
    files:
      lib/answer.dart: lib/answer.dart
  - id: api_breaking
    kind: api_breaking
    description: Breaks the answer API.
    root: negative_cases/api_breaking
    files:
      lib/answer.dart: lib/answer.dart
''');
  await _writeFile(bundle, 'instruction.md', instruction);
  await _writeFile(bundle, 'baseline/pubspec.yaml', '''
name: file_backed_answer
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
  await _writeFile(bundle, 'baseline/lib/answer.dart', 'int answer() => 41;\n');
  await _writeFile(bundle, 'baseline/test/answer_test.dart', '''
import 'package:file_backed_answer/answer.dart';
import 'package:test/test.dart';

void main() {
  test('answer is an integer', () => expect(answer(), isA<int>()));
}
''');
  await _writeFile(bundle, 'hidden_tests/$hiddenTestPath', '''
import 'package:file_backed_answer/answer.dart';
import 'package:test/test.dart';

void main() {
  test('answer is fixed', () => expect(answer(), 42));
}
''');
  await _writeFile(bundle, 'solution/lib/answer.dart', 'int answer() => 42;\n');
  await _writeFile(
    bundle,
    'negative_cases/noop/lib/answer.dart',
    'int answer() => 41;\n',
  );
  await _writeFile(
    bundle,
    'negative_cases/api_breaking/lib/answer.dart',
    'void answer() {}\n',
  );
  return bundle;
}

Future<void> _writeFile(
  Directory bundle,
  String relativePath,
  String content,
) async {
  final file = File(p.join(bundle.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
