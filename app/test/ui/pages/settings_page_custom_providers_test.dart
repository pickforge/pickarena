import 'dart:io';

import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(SettingsRepository repo, {TmpDirManager? tmpDirManager}) {
  final manager =
      tmpDirManager ??
      TmpDirManager(
        root: Directory.systemTemp.createTempSync('settings_page_tmp_'),
      );
  return MaterialApp(
    home: Scaffold(
      body: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SettingsRepository>.value(value: repo),
          RepositoryProvider<TmpDirManager>.value(value: manager),
        ],
        child: const SettingsPage(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Add dialog Cancel writes nothing', (tester) async {
    final repo = SettingsRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add provider'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add provider'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Test',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'ID'), 'test');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Base URL'),
      'http://test:8080/v1',
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    final providers = await repo.getCustomLocalProviders();
    expect(providers, isEmpty);
  });

  testWidgets('Add dialog Save trims fields and persists headers/efforts', (
    tester,
  ) async {
    final repo = SettingsRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add provider'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add provider'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      '  Codex  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ID'),
      '  codex  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Base URL'),
      ' http://127.0.0.1:9000/v1 ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'API key (optional)'),
      ' sk-test ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Default efforts (comma-separated)'),
      ' low , , medium ',
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    final providers = await repo.getCustomLocalProviders();
    expect(providers.length, 1);
    expect(providers.first.id, 'codex');
    expect(providers.first.name, 'Codex');
    expect(providers.first.defaultEfforts, ['low', 'medium']);

    final url = await repo.getBaseUrlOverride('codex');
    expect(url, 'http://127.0.0.1:9000/v1');
    final key = await repo.getApiKey('codex');
    expect(key, 'sk-test');
  });

  testWidgets('Save judge with stale id persists null', (tester) async {
    final repo = SettingsRepository();
    await repo.setJudgeProviderId('stale_custom_provider');
    await repo.setJudgeModelId('some-model');

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Save judge'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save judge'));
    await tester.pumpAndSettle();

    expect(await repo.getJudgeProviderId(), isNull);
  });

  testWidgets('Delete clears entry from storage', (tester) async {
    final repo = SettingsRepository();
    await repo.setBaseUrlOverride('temp', 'http://temp:8080/v1');
    await repo.setCustomLocalProviders([
      const CustomLocalProviderEntry(id: 'temp', name: 'Temp'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Temp'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final deleteButtons = find.byIcon(Icons.delete);
    expect(deleteButtons, findsAtLeastNWidgets(1));
    await tester.tap(deleteButtons.last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    final providers = await repo.getCustomLocalProviders();
    expect(providers, isEmpty);
    expect(await repo.getApiKey('temp'), isNull);
    expect(await repo.getBaseUrlOverride('temp'), isNull);
  });
}
