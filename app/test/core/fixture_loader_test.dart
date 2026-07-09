import 'dart:io';

import 'package:dart_arena/core/fixture_loader.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('FixtureLoader loads listed files keyed by relative path', () async {
    final root = await Directory.systemTemp.createTemp('fixture_loader_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    await File(
      p.join(root.path, 'fixtures/pubspec.yaml'),
    ).create(recursive: true);
    await File(
      p.join(root.path, 'fixtures/pubspec.yaml'),
    ).writeAsString('name: filesystem_fixture\n');
    await File(
      p.join(root.path, 'fixtures/lib/answer.dart'),
    ).create(recursive: true);
    await File(
      p.join(root.path, 'fixtures/lib/answer.dart'),
    ).writeAsString('int answer() => 42;\n');
    final loader = FixtureLoader(
      assetRoot: 'fixtures',
      files: const ['pubspec.yaml', 'lib/answer.dart'],
      repoRoot: root.path,
    );

    final map = await loader.load();

    expect(map.keys, {'pubspec.yaml', 'lib/answer.dart'});
    expect(map['pubspec.yaml'], contains('filesystem_fixture'));
    expect(map['lib/answer.dart'], contains('answer'));
  });

  test('FixtureLoader throws when a filesystem fixture is missing', () async {
    final root = await Directory.systemTemp.createTemp('fixture_missing_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final loader = FixtureLoader(
      assetRoot: 'fixtures',
      files: const ['pubspec.yaml'],
      repoRoot: root.path,
    );

    await expectLater(loader.load(), throwsA(isA<FileSystemException>()));
  });
}
