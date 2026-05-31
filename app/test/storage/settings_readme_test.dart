import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('readme path defaults to null', () async {
    final repo = SettingsRepository();
    expect(await repo.getReadmePath(), isNull);
  });

  test('readme path roundtrips', () async {
    final repo = SettingsRepository();
    await repo.setReadmePath('/tmp/README.md');
    expect(await repo.getReadmePath(), '/tmp/README.md');
  });

  test('setting null clears the value', () async {
    final repo = SettingsRepository();
    await repo.setReadmePath('/tmp/README.md');
    await repo.setReadmePath(null);
    expect(await repo.getReadmePath(), isNull);
  });

  test('setting empty string clears the value', () async {
    final repo = SettingsRepository();
    await repo.setReadmePath('/tmp/README.md');
    await repo.setReadmePath('');
    expect(await repo.getReadmePath(), isNull);
  });
}
