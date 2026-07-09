import 'package:test/test.dart';

import '../support/settings_store_test_utils.dart';

void main() {
  test('readme path defaults to null', () async {
    final repo = await newFileSettingsStore();
    expect(await repo.getReadmePath(), isNull);
  });

  test('readme path roundtrips', () async {
    final repo = await newFileSettingsStore();
    await repo.setReadmePath('/tmp/README.md');
    expect(await repo.getReadmePath(), '/tmp/README.md');
  });

  test('setting null clears the value', () async {
    final repo = await newFileSettingsStore();
    await repo.setReadmePath('/tmp/README.md');
    await repo.setReadmePath(null);
    expect(await repo.getReadmePath(), isNull);
  });

  test('setting empty string clears the value', () async {
    final repo = await newFileSettingsStore();
    await repo.setReadmePath('/tmp/README.md');
    await repo.setReadmePath('');
    expect(await repo.getReadmePath(), isNull);
  });
}
