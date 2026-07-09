import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _original = '''
class A {
  int x() => 1;
  int y() => 2;
  int z() => 3;
}
''';

class _Task extends BenchmarkTask {
  _Task(this._fixtures, {this.track = BenchmarkTrack.codegen});
  final Map<String, String> _fixtures;

  @override
  String get id => 'task';
  @override
  Category get category => Category.bugFix;
  @override
  final BenchmarkTrack track;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => _fixtures;
  @override
  String get generatedCodePath => 'lib/a.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<EvaluationContext> _ctxWith(
  String workdirContents, {
  String? extractedCode,
}) async {
  return _ctxWithFiles(
    fixtures: {'lib/a.dart': _original},
    workdirContents: {'lib/a.dart': workdirContents},
    extractedCode: extractedCode,
  );
}

Future<EvaluationContext> _ctxWithFiles({
  required Map<String, String> fixtures,
  required Map<String, String> workdirContents,
  String? extractedCode,
  BenchmarkTrack track = BenchmarkTrack.codegen,
}) async {
  final dir = await Directory.systemTemp.createTemp('dart_arena_diff_');
  addTearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  for (final entry in workdirContents.entries) {
    final file = File(p.join(dir.path, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
  return EvaluationContext(
    workDir: dir,
    response: ModelResponse(
      rawText: '',
      extractedCode: extractedCode,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    task: _Task(fixtures, track: track),
  );
}

void main() {
  test('identical contents score 1.0', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(await _ctxWith(_original));
    expect(r.score, closeTo(1.0, 1e-9));
    expect(r.passed, isTrue);
  });

  test('small diff produces score between 0 and 1', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified = _original.replaceFirst('=> 1;', '=> 10;');
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(1.0));
    expect(r.score, greaterThan(0.5));
  });

  test('large diff drives score toward 0 without failing', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified =
        '${List.generate(40, (i) => '// new line $i').join('\n')}\n';
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(math.exp(-1.0)));
    expect(r.passed, isTrue);
  });

  test('30-line legitimate fix no longer fails', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified =
        '${List.generate(30, (i) => 'final value$i = $i;').join('\n')}\n';
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(0.3));
    expect(r.passed, isTrue);
  });

  test('measures all fixture files in the workspace fallback', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(
      await _ctxWithFiles(
        fixtures: const {
          'lib/a.dart': 'int a() => 1;\n',
          'lib/b.dart': 'int b() => 1;\n',
        },
        workdirContents: const {
          'lib/a.dart': 'int a() => 2;\n',
          'lib/b.dart': 'int b() => 2;\n',
        },
      ),
    );

    expect(r.passed, isTrue);
    expect(r.details['measurement_source'], 'workspace_fixtures');
    expect(r.details['changed_file_count'], 2);
    expect(r.details['compared_file_count'], 2);
    expect(r.details['changed_lines'], 4);
  });

  test('uses captured agent patch when available', () async {
    const patch = '''
diff --git a/lib/a.dart b/lib/a.dart
index 1111111..2222222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1 +1 @@
-int a() => 1;
+int a() => 2;
diff --git a/lib/b.dart b/lib/b.dart
index 3333333..4444444 100644
--- a/lib/b.dart
+++ b/lib/b.dart
@@ -1 +1 @@
-int b() => 1;
+int b() => 2;
''';
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(
      await _ctxWithFiles(
        fixtures: const {
          'lib/a.dart': 'int a() => 1;\n',
          'lib/b.dart': 'int b() => 1;\n',
        },
        workdirContents: const {
          'lib/a.dart': 'int a() => 1;\n',
          'lib/b.dart': 'int b() => 1;\n',
        },
        extractedCode: patch,
        track: BenchmarkTrack.agentic,
      ),
    );

    expect(r.passed, isTrue);
    expect(r.details['measurement_source'], 'agent_patch');
    expect(r.details['changed_file_count'], 2);
    expect(r.details['compared_file_count'], 2);
    expect(r.details['changed_lines'], 4);
  });

  test('counts hunk lines whose content starts with pluses', () async {
    const patch = '''
diff --git a/lib/a.dart b/lib/a.dart
index 1111111..2222222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1 +1,2 @@
 int a() => 1;
+++counter;
''';
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(
      await _ctxWithFiles(
        fixtures: const {'lib/a.dart': 'int a() => 1;\n'},
        workdirContents: const {'lib/a.dart': 'int a() => 1;\n'},
        extractedCode: patch,
        track: BenchmarkTrack.agentic,
      ),
    );

    expect(r.passed, isTrue);
    expect(r.details['measurement_source'], 'agent_patch');
    expect(r.details['changed_file_count'], 1);
    expect(r.details['changed_lines'], 1);
  });

  test('marks captured agent patch telemetry as truncated', () async {
    const patch = '''
diff --git a/lib/a.dart b/lib/a.dart
index 1111111..2222222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1 +1 @@
-int a() => 1;
+int a() => 2;

[patch truncated at 262144 characters]
''';
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(
      await _ctxWithFiles(
        fixtures: const {'lib/a.dart': 'int a() => 1;\n'},
        workdirContents: const {'lib/a.dart': 'int a() => 1;\n'},
        extractedCode: patch,
        track: BenchmarkTrack.agentic,
      ),
    );

    expect(r.passed, isTrue);
    expect(r.details['measurement_source'], 'agent_patch');
    expect(r.details['changed_lines'], 2);
    expect(r.details['patch_truncated'], isTrue);
  });

  test('codegen track ignores patch-looking extracted code', () async {
    const patch = '''
diff --git a/lib/a.dart b/lib/a.dart
@@ -1 +1 @@
-int a() => 1;
+int a() => 2;
''';
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(
      await _ctxWithFiles(
        fixtures: const {'lib/a.dart': 'int a() => 1;\n'},
        workdirContents: const {'lib/a.dart': 'int a() => 1;\n'},
        extractedCode: patch,
      ),
    );

    expect(r.passed, isTrue);
    expect(r.details['measurement_source'], 'workspace_fixtures');
    expect(r.details['changed_lines'], 0);
  });

  test('missing fixture file counts as deletion and passes', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_diff_miss_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final ctx = EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _Task({'lib/a.dart': _original}),
    );
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(ctx);
    expect(r.score, lessThan(1.0));
    expect(r.passed, isTrue);
    expect(r.details['missing_file_count'], 1);
  });

  test('missing diff source remains diagnostic-only', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_diff_empty_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final ctx = EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _Task(const {}),
    );
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(ctx);
    expect(r.score, 0.0);
    expect(r.passed, isTrue);
    expect(r.rationale, contains('missing'));
  });
}
