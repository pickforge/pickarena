import 'dart:io';

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

  test('sanitizes ::effort and / in modelId path segment', () async {
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
    expect(partsA, contains('deepseek-v4-pro%3A%3Ahigh'));
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
    expect(partsB, contains('openai%2Fgpt-4o'));
    expect(partsB, isNot(contains('openai/gpt-4o')));

    root.deleteSync(recursive: true);
  });
}
