import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter/services.dart';

class OffByOnePaginationTask extends BenchmarkTask {
  @override
  String get id => 'bug.off_by_one_pagination';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => '''
You are given a Dart class `Paginator<T>` in `lib/pagination.dart` that has off-by-one bugs.
There are tests in `test/pagination_test.dart` that currently fail.

Return ONLY the corrected contents of `lib/pagination.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;
  static final Map<String, String> _fixtures = {};

  static Future<void> loadAssets() async {
    if (_fixtures.isNotEmpty) return;
    const base = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
    _fixtures['pubspec.yaml'] =
        await rootBundle.loadString('$base/pubspec.yaml');
    _fixtures['lib/pagination.dart'] =
        await rootBundle.loadString('$base/lib/pagination.dart');
    _fixtures['test/pagination_test.dart'] =
        await rootBundle.loadString('$base/test/pagination_test.dart');
  }

  @override
  String get generatedCodePath => 'lib/pagination.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) =>
      [CompileEvaluator()];
}
