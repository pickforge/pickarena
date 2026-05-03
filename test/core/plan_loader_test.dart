import 'package:dart_arena/core/plan_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'PlanLoader.load returns a ReferencePlan with the loaded asset text',
      (tester) async {
    final plan = await PlanLoader.load(
      assetPath:
          'lib/tasks/bug_fix/fixtures/off_by_one_pagination/pubspec.yaml',
      version: 1,
    );
    expect(plan.version, 1);
    expect(plan.markdown, isNotEmpty);
    expect(plan.markdown, contains('off_by_one_pagination'));
  });

  testWidgets('PlanLoader throws when the asset path is missing',
      (tester) async {
    await expectLater(
      () => PlanLoader.load(
        assetPath: 'lib/tasks/planning_and_execution/plans/missing.md',
        version: 1,
      ),
      throwsA(isA<FlutterError>()),
    );
  });
}
