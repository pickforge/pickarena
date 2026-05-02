@Tags(['flutter'])
library;

import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/widget_tree_evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _DummyTask extends BenchmarkTask {
  @override
  String get id => 'dummy';
  @override
  Category get category => Category.uiFromSpec;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

void main() {
  test('passing widget test scores 1.0', () async {
    final root =
        await Directory.systemTemp.createTemp('dart_arena_widget_eval_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

class Greeting extends StatelessWidget {
  const Greeting({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Text('hello')));
}
''');
    Directory(p.join(dir.path, 'test', 'widget')).createSync(recursive: true);
    File(p.join(dir.path, 'test', 'widget', 'greeting_test.dart'))
        .writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmp/tmp.dart';

void main() {
  testWidgets('renders hello', (tester) async {
    await tester.pumpWidget(const Greeting());
    expect(find.text('hello'), findsOneWidget);
  });
}
''');

    expect(
      await WorkdirManager(root: root).prepare(dir),
      isA<PrepareOk>(),
    );
    final r = await WidgetTreeEvaluator().evaluate(EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _DummyTask(),
    ));

    expect(r.passed, isTrue);
    expect(r.score, 1.0);

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
