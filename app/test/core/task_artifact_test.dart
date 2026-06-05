import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_artifact.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'default manifest exports public task metadata without private content',
    () async {
      final manifest = await TaskArtifactManifest.fromTask(_ArtifactTask());

      expect(manifest.schemaVersion, TaskArtifactManifest.currentSchemaVersion);
      expect(manifest.id, 'ui.artifact');
      expect(manifest.version, 3);
      expect(manifest.category, 'uiFromSpec');
      expect(manifest.track, 'agentic');
      expect(manifest.tags, ['accessibility', 'ui']);
      expect(manifest.difficulty, 'hard');
      expect(manifest.isFlutter, isTrue);
      expect(manifest.generatedCodePath, 'lib/widget.dart');
      expect(manifest.prompt.text, contains('Fix the widget'));
      expect(manifest.prompt.sha256, hasLength(64));
      expect(manifest.environment.timeoutSeconds, 120);
      expect(manifest.environment.platformRequirements, ['linux']);
      expect(manifest.environment.allowInternet, isFalse);
      expect(manifest.environment.resourceLimits.toJson(), {
        'cpus': 2,
        'memoryMb': 8192,
        'maxProcesses': 64,
        'maxOutputBytes': 1048576,
      });

      expect(manifest.workspace.files.map((file) => file.path), [
        'lib/widget.dart',
        'pubspec.yaml',
        'test/widget_test.dart',
      ]);
      expect(
        manifest.workspace.files
            .singleWhere((file) => file.path == 'test/widget_test.dart')
            .role,
        'public_test',
      );
      expect(
        manifest.workspace.files.every((file) => file.visibility == 'public'),
        isTrue,
      );
      expect(manifest.hiddenVerifiers.single.id, 'behavior_hidden');
      expect(manifest.hiddenVerifiers.single.files, isEmpty);
      expect(manifest.referenceFiles, isEmpty);
    },
  );

  test(
    'private export option includes hidden verifier and reference hashes',
    () async {
      final manifest = await TaskArtifactManifest.fromTask(
        _ArtifactTask(),
        options: const TaskArtifactExportOptions(
          includeHiddenVerifiers: true,
          includeReferenceSolution: true,
        ),
      );

      expect(
        manifest.hiddenVerifiers.single.files.single.path,
        'test/_hidden/widget_hidden_test.dart',
      );
      expect(manifest.hiddenVerifiers.single.files.single.visibility, 'hidden');
      expect(manifest.referenceFiles.single.path, 'lib/widget.dart');
      expect(manifest.referenceFiles.single.role, 'reference_solution');
      expect(manifest.referenceFiles.single.visibility, 'private');
    },
  );

  test('manifest JSON round trips through disk', () async {
    final root = await Directory.systemTemp.createTemp('task_manifest_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final file = File(p.join(root.path, 'task_manifest.v1.json'));
    final manifest = await TaskArtifactManifest.fromTask(_ArtifactTask());

    await writeTaskManifestJson(file, manifest);
    final decoded = await readTaskManifestJson(file);

    expect(decoded.toJson(), manifest.toJson());
  });

  test('default manifest omits local fixture root paths', () async {
    final manifest = await TaskArtifactManifest.fromTask(
      _ArtifactTask(fixtureRootPath: '/home/dev/private/task'),
    );

    expect(manifest.workspace.fixtureRootPath, isNull);
    expect(
      manifest.toJson()['workspace'] as Map<String, Object?>,
      isNot(contains('fixtureRootPath')),
    );
  });
}

class _ArtifactTask extends BenchmarkTask {
  _ArtifactTask({this.fixtureRootPath});

  final String? fixtureRootPath;

  @override
  String get id => 'ui.artifact';

  @override
  int get version => 3;

  @override
  Category get category => Category.uiFromSpec;

  @override
  BenchmarkTrack get track => BenchmarkTrack.agentic;

  @override
  Set<TaskTag> get tags => const {TaskTag.ui, TaskTag.accessibility};

  @override
  TaskDifficulty get difficulty => TaskDifficulty.hard;

  @override
  Duration? get timeout => const Duration(seconds: 120);

  @override
  Set<TaskPlatform> get platformRequirements => const {TaskPlatform.linux};

  @override
  TaskResourceLimits get resourceLimits => const TaskResourceLimits(
    cpus: 2,
    memoryMb: 8192,
    maxProcesses: 64,
    maxOutputBytes: 1024 * 1024,
  );

  @override
  String get prompt => 'Fix the widget.';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': 'name: artifact\n',
    'lib/widget.dart': 'class Widget {}\n',
    'test/widget_test.dart': 'void main() {}\n',
    '_hidden/top_level_test.dart': 'private\n',
    'hidden/top_level_test.dart': 'private\n',
    'task_qa/admission_report.json': '{}\n',
    'author_notes/notes.md': 'private\n',
    '_author/notes.md': 'private\n',
    'test/author_notes.md': 'private\n',
    'test/hidden/leaked_test.dart': 'private\n',
    'test/_hidden/leaked_test.dart': 'private\n',
    'test/_reference/leaked_test.dart': 'private\n',
    'test/reference/leaked_test.dart': 'private\n',
    'test/qa_report.md': 'private\n',
    'test/task_qa_report.md': 'private\n',
    'reference/lib/widget.dart': 'private\n',
  };

  @override
  TaskWorkspace get workspace => TaskWorkspace(
    fixtureRootPath: fixtureRootPath,
    files: fixtures,
    instruction: prompt,
  );

  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'behavior_hidden',
      files: {'test/_hidden/widget_hidden_test.dart': 'void main() {}\n'},
      testPath: 'test/_hidden/widget_hidden_test.dart',
    ),
  ];

  @override
  ReferenceSolution? get referenceSolution {
    return const ReferenceFileSolution({'lib/widget.dart': 'class Fixed {}\n'});
  }

  @override
  String get generatedCodePath => 'lib/widget.dart';

  @override
  bool get isFlutter => true;

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}
