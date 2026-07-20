import 'dart:io';

import 'package:path/path.dart' as p;

enum TaskBundleCompatibilityMutation {
  none,
  missingManifest,
  corruptManifest,
  instructionTraversal,
  missingHiddenVerifier,
  instructionSymlink,
}

class TaskBundleCompatibilityFixture {
  const TaskBundleCompatibilityFixture(
    this.name, {
    required this.accepted,
    this.mutation = TaskBundleCompatibilityMutation.none,
    this.requiresSymlink = false,
  });

  final String name;
  final bool accepted;
  final TaskBundleCompatibilityMutation mutation;
  final bool requiresSymlink;
}

const taskBundleCompatibilityFixtures = [
  TaskBundleCompatibilityFixture('valid bundle', accepted: true),
  TaskBundleCompatibilityFixture(
    'missing manifest',
    accepted: false,
    mutation: TaskBundleCompatibilityMutation.missingManifest,
  ),
  TaskBundleCompatibilityFixture(
    'corrupt manifest',
    accepted: false,
    mutation: TaskBundleCompatibilityMutation.corruptManifest,
  ),
  TaskBundleCompatibilityFixture(
    'traversing instruction path',
    accepted: false,
    mutation: TaskBundleCompatibilityMutation.instructionTraversal,
  ),
  TaskBundleCompatibilityFixture(
    'missing hidden verifier fixture',
    accepted: false,
    mutation: TaskBundleCompatibilityMutation.missingHiddenVerifier,
  ),
  TaskBundleCompatibilityFixture(
    'symlinked instruction',
    accepted: false,
    mutation: TaskBundleCompatibilityMutation.instructionSymlink,
    requiresSymlink: true,
  ),
];

Future<Directory> writeTaskBundleCompatibilityFixture(
  Directory root,
  TaskBundleCompatibilityFixture fixture,
) async {
  final bundle = await writeAnswerFileBackedBundle(root);
  final manifest = File(p.join(bundle.path, 'task.yaml'));
  switch (fixture.mutation) {
    case TaskBundleCompatibilityMutation.none:
      break;
    case TaskBundleCompatibilityMutation.missingManifest:
      await manifest.delete();
    case TaskBundleCompatibilityMutation.corruptManifest:
      await manifest.writeAsString('workspace: [\n');
    case TaskBundleCompatibilityMutation.instructionTraversal:
      final outsideInstruction = File(p.join(root.path, 'outside.md'));
      await outsideInstruction.writeAsString('Outside the bundle.\n');
      await manifest.writeAsString(
        (await manifest.readAsString()).replaceFirst(
          'instructionPath: instruction.md',
          'instructionPath: ../outside.md',
        ),
      );
    case TaskBundleCompatibilityMutation.missingHiddenVerifier:
      await File(
        p.join(
          bundle.path,
          'hidden_tests',
          'test',
          '_hidden',
          'answer_hidden_test.dart',
        ),
      ).delete();
    case TaskBundleCompatibilityMutation.instructionSymlink:
      final instruction = File(p.join(bundle.path, 'instruction.md'));
      final outsideInstruction = File(p.join(root.path, 'outside.md'));
      await outsideInstruction.writeAsString('Outside the bundle.\n');
      await instruction.delete();
      await Link(instruction.path).create(outsideInstruction.path);
  }
  return bundle;
}

Future<Directory> writeAnswerFileBackedBundle(
  Directory root, {
  String directoryName = 'answer_fix',
  String id = 'file.answer_fix',
  int version = 2,
  String category = 'bug_fix',
  String track = 'codegen',
  String generatedCodePath = 'lib/answer.dart',
  String hiddenVerifierId = 'answer_hidden',
  String hiddenTestPath = 'test/_hidden/answer_hidden_test.dart',
  String instruction = 'Make answer() return 42.\n',
  String? judgeRubricPath,
  String? judgeRubricText,
  bool includeRequiredNegativeCaseKinds = true,
  bool isFlutter = false,
}) async {
  final bundle = Directory(p.join(root.path, directoryName));
  final judgeRubricYaml = judgeRubricPath == null
      ? ''
      : 'judgeRubricPath: $judgeRubricPath\n';
  final requiredNegativeCasesYaml = includeRequiredNegativeCaseKinds
      ? '''
requiredNegativeCaseKinds:
  - noop
  - api_breaking
  - overfit
'''
      : '';
  await _writeFile(bundle, 'task.yaml', '''
schemaVersion: 1
id: $id
version: $version
category: $category
track: $track
tags:
  - bugfix
difficulty: easy
platformRequirements:
  - linux
timeoutSeconds: 60
release:
  corpus: public_diagnostic
  status: active
network: false
resources:
  cpus: 2
  memory_mb: 8192
  max_processes: 64
  max_output_bytes: 1048576
generatedCodePath: $generatedCodePath
isFlutter: $isFlutter
${judgeRubricYaml}instructionPath: instruction.md
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
${requiredNegativeCasesYaml}negativeCases:
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
  - id: overfit_public_surface
    kind: overfit
    description: Matches visible coverage while missing hidden behavior.
    root: negative_cases/overfit
    files:
      lib/answer.dart: lib/answer.dart
''');
  await _writeFile(bundle, 'instruction.md', instruction);
  if (judgeRubricPath != null) {
    await _writeFile(
      bundle,
      judgeRubricPath,
      judgeRubricText ?? 'Score whether answer() returns 42.\n',
    );
  }
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
  await _writeFile(
    bundle,
    'negative_cases/overfit/lib/answer.dart',
    'int answer() => 0;\n',
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
