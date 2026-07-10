import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_arena/core/task_bundle_digest.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('corpus manifest digest', () {
    test('is deterministic and changes with task version or bundle digest', () {
      final a = List.filled(64, 'a').join();
      final b = List.filled(64, 'b').join();
      final c = List.filled(64, 'c').join();
      final first = [
        CorpusManifestEntry(
          taskId: 'task.b',
          taskVersion: 1,
          taskBundleDigest: b,
        ),
        CorpusManifestEntry(
          taskId: 'task.a',
          taskVersion: 1,
          taskBundleDigest: a,
        ),
      ];
      final digest = corpusManifestDigestSha256(first);

      expect(corpusManifestDigestSha256(first.reversed), digest);
      expect(
        corpusManifestDigestSha256([
          CorpusManifestEntry(
            taskId: 'task.a',
            taskVersion: 2,
            taskBundleDigest: a,
          ),
          first.first,
        ]),
        isNot(digest),
      );
      expect(
        corpusManifestDigestSha256([
          CorpusManifestEntry(
            taskId: 'task.a',
            taskVersion: 1,
            taskBundleDigest: c,
          ),
          first.first,
        ]),
        isNot(digest),
      );
    });
  });

  test('task bundle digest follows declared files and excludes qa', () async {
    final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final first = Directory(p.join(root.path, 'first'));
    final second = Directory(p.join(root.path, 'second'));
    await _writeBundle(first, reverseOrder: false);
    await _writeBundle(second, reverseOrder: true);

    final firstDigest = await taskBundleDigestSha256(first);
    final secondDigest = await taskBundleDigestSha256(second);

    expect(firstDigest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(secondDigest, firstDigest);

    await _writeFile(first, 'qa/admission_report.json', '{"changed":true}\n');
    expect(await taskBundleDigestSha256(first), firstDigest);

    await _writeFile(first, 'baseline/lib/unused.dart', 'changed\n');
    expect(await taskBundleDigestSha256(first), firstDigest);

    await _writeFile(first, 'baseline/lib/main.dart', 'void main() {}\n');
    expect(await taskBundleDigestSha256(first), isNot(firstDigest));
  });

  test(
    'task bundle digest rejects declared files outside digest roots',
    () async {
      final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final bundle = Directory(p.join(root.path, 'bundle'));
      await _writeBundle(bundle, workspaceRoot: 'qa');
      await _writeFile(bundle, 'qa/lib/main.dart', 'void main() => 1;\n');

      expect(
        () => taskBundleDigestSha256(bundle),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('task bundle digest includes declared judge rubric files', () async {
    final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bundle = Directory(p.join(root.path, 'bundle'));
    await _writeBundle(bundle, judgeRubricPath: 'rubrics/judge.md');
    await _writeFile(bundle, 'rubrics/judge.md', 'Score correctness.\n');

    final digest = await taskBundleDigestSha256(bundle);

    await _writeFile(
      bundle,
      'rubrics/judge.md',
      'Score correctness and scope.\n',
    );
    expect(await taskBundleDigestSha256(bundle), isNot(digest));
  });

  test('task bundle digest rejects backslashes in manifest paths', () async {
    final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bundle = Directory(p.join(root.path, 'bundle'));
    await _writeBundle(bundle);
    final manifest = File(p.join(bundle.path, 'task.yaml'));
    await manifest.writeAsString(
      (await manifest.readAsString()).replaceFirst(
        'instructionPath: instruction.md',
        r'instructionPath: instruction\path.md',
      ),
    );

    expect(() => taskBundleDigestSha256(bundle), throwsA(isA<ArgumentError>()));
  });

  test('task bundle digest ignores undeclared OS metadata files', () async {
    final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bundle = Directory(p.join(root.path, 'bundle'));
    await _writeBundle(bundle, reverseOrder: false);

    final digest = await taskBundleDigestSha256(bundle);

    await _writeFile(bundle, 'baseline/.DS_Store', 'finder\n');
    await _writeFile(bundle, 'hidden_tests/Thumbs.db', 'thumbs\n');
    await _writeFile(bundle, 'solution/desktop.ini', 'desktop\n');
    await _writeFile(bundle, 'negative_cases/noop/._main.dart', 'apple\n');

    expect(await taskBundleDigestSha256(bundle), digest);
  });

  test(
    'task bundle digest uses forward slash paths in canonical stream',
    () async {
      final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final bundle = Directory(p.join(root.path, 'bundle'));
      final files = await _writeBundle(bundle, reverseOrder: false);

      expect(await taskBundleDigestSha256(bundle), _canonicalDigest(files));
    },
  );

  test('task bundle digest rejects symlinks under digest roots', () async {
    final root = await Directory.systemTemp.createTemp('task_bundle_digest_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bundle = Directory(p.join(root.path, 'bundle'));
    await _writeBundle(bundle, reverseOrder: false);
    final link = Link(p.join(bundle.path, 'baseline', 'link.dart'));
    try {
      await link.create('lib/main.dart');
    } on FileSystemException {
      return;
    }

    expect(
      () => taskBundleDigestSha256(bundle),
      throwsA(isA<FileSystemException>()),
    );
  });
}

Future<Map<String, String>> _writeBundle(
  Directory bundle, {
  bool reverseOrder = false,
  String workspaceRoot = 'baseline',
  String? judgeRubricPath,
}) async {
  final taskYaml = _taskYaml(
    workspaceRoot: workspaceRoot,
    judgeRubricPath: judgeRubricPath,
  );
  final files = {
    'task.yaml': taskYaml,
    'instruction.md': 'Fix the task.\n',
    '$workspaceRoot/lib/main.dart': 'void main() => 1;\n',
    'baseline/lib/unused.dart': 'unused\n',
    'hidden_tests/test/main_test.dart': 'hidden\n',
    'solution/lib/main.dart': 'void main() => 2;\n',
    'negative_cases/noop/lib/main.dart': 'void main() => 1;\n',
    'qa/admission_report.json': '{}\n',
  };
  final writes = [
    for (final entry in files.entries)
      () => _writeFile(bundle, entry.key, entry.value),
  ];
  for (final write in reverseOrder ? writes.reversed : writes) {
    await write();
  }
  return files;
}

String _taskYaml({required String workspaceRoot, String? judgeRubricPath}) =>
    '''
instructionPath: instruction.md
${judgeRubricPath == null ? '' : 'judgeRubricPath: $judgeRubricPath\n'}workspace:
  root: $workspaceRoot
  files:
    lib/main.dart: lib/main.dart
hiddenVerifiers:
  - id: hidden
    testPath: test/main_test.dart
    root: hidden_tests
    files:
      test/main_test.dart: test/main_test.dart
reference:
  type: files
  root: solution
  files:
    lib/main.dart: lib/main.dart
negativeCases:
  - id: noop
    description: Leaves the original answer unchanged.
    kind: noop
    root: negative_cases/noop
    files:
      lib/main.dart: lib/main.dart
''';

String _canonicalDigest(Map<String, String> files) {
  final canonicalFiles = {
    for (final path in [
      'task.yaml',
      'instruction.md',
      'baseline/lib/main.dart',
      'hidden_tests/test/main_test.dart',
      'solution/lib/main.dart',
      'negative_cases/noop/lib/main.dart',
    ])
      path: utf8.encode(files[path]!),
  };
  final bytesBuilder = BytesBuilder(copy: false);
  for (final entry
      in canonicalFiles.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))) {
    bytesBuilder.add(
      utf8.encode('${entry.key}\u0000${entry.value.length}\u0000'),
    );
    bytesBuilder.add(entry.value);
    bytesBuilder.add(const [0]);
  }
  return sha256.convert(bytesBuilder.takeBytes()).toString();
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
