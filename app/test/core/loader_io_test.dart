import 'dart:io';

import 'package:dart_arena/core/fixture_loader_io.dart';
import 'package:dart_arena/core/plan_loader_io.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'IO FixtureLoader fallback reads asset-relative files from repo root',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_loader_io_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      await File(
        p.join(tmp.path, 'lib', 'tasks', 'fixture', 'pubspec.yaml'),
      ).create(recursive: true);
      await File(
        p.join(tmp.path, 'lib', 'tasks', 'fixture', 'pubspec.yaml'),
      ).writeAsString('name: fixture\n');

      final loaded = await loadFixtureFiles(
        assetRoot: 'lib/tasks/fixture',
        files: const ['pubspec.yaml'],
        repoRoot: tmp.path,
      );

      expect(loaded, {'pubspec.yaml': 'name: fixture\n'});
    },
  );

  test(
    'IO PlanLoader fallback reads asset-relative plans from repo root',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_plan_io_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final planFile = File(p.join(tmp.path, 'lib', 'tasks', 'plans', 'p.md'));
      await planFile.create(recursive: true);
      await planFile.writeAsString('# plan\n');

      final markdown = await loadPlanMarkdown(
        assetPath: 'lib/tasks/plans/p.md',
        repoRoot: tmp.path,
      );

      expect(markdown, '# plan\n');
    },
  );
}
