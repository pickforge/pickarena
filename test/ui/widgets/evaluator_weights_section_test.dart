import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/widgets/evaluator_weights_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(SettingsRepository repo) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: RepositoryProvider<SettingsRepository>.value(
          value: repo,
          child: const EvaluatorWeightsSection(),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders one row per evaluator id', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();
    for (final id in defaultEvaluatorWeights.keys) {
      expect(find.text(id), findsOneWidget,
          reason: 'expected row for evaluator id "$id"');
    }
  });

  testWidgets('row badge says Default when value matches default',
      (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();
    expect(
        find.text('Default'), findsNWidgets(defaultEvaluatorWeights.length));
    expect(find.text('Override'), findsNothing);
  });

  testWidgets('editing a row flips its badge to Override', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();

    final compileField = find.byKey(const ValueKey('weight-field-compile'));
    await tester.enterText(compileField, '2.0');
    await tester.pumpAndSettle();

    expect(find.text('Override'), findsOneWidget);
    expect(find.text('Default'),
        findsNWidgets(defaultEvaluatorWeights.length - 1));
  });

  testWidgets('per-row Reset clears the override field', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();

    final compileField = find.byKey(const ValueKey('weight-field-compile'));
    await tester.enterText(compileField, '2.0');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('weight-reset-compile')));
    await tester.pumpAndSettle();

    expect(find.text('Override'), findsNothing);
    expect(
      tester.widget<TextField>(compileField).controller!.text,
      '',
    );
  });

  testWidgets('Save persists only rows that differ from defaults',
      (tester) async {
    final repo = SettingsRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('weight-field-compile')),
      '2.0',
    );
    await tester.pumpAndSettle();

    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    final stored = await repo.getEvaluatorWeights();
    expect(stored['compile'], 2.0);
    // Other rows kept their defaults
    expect(stored['analyze'], defaultEvaluatorWeights['analyze']);
    expect(stored['test'], defaultEvaluatorWeights['test']);
  });

  testWidgets('invalid input disables Save', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('weight-field-compile')),
      '-1',
    );
    await tester.pumpAndSettle();

    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(saveBtn);
    expect(btn.onPressed, isNull);
  });
}
