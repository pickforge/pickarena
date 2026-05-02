import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Ollama Local + Droid are always enabled', () async {
    final providers = await buildEnabledProviders(SettingsRepository());
    final ids = providers.map((p) => p.id).toList();
    expect(ids, containsAll(['ollama_local', 'droid']));
  });

  test('cloud providers appear once their key is set', () async {
    final repo = SettingsRepository();
    expect(
      (await buildEnabledProviders(repo)).any((p) => p.id == 'opencode_zen'),
      isFalse,
    );
    await repo.setApiKey('opencode_zen', 'sk');
    expect(
      (await buildEnabledProviders(repo)).any((p) => p.id == 'opencode_zen'),
      isTrue,
    );
  });

  test('no cloud providers appear with empty keys', () async {
    final providers = await buildEnabledProviders(SettingsRepository());
    final ids = providers.map((p) => p.id).toSet();
    expect(ids, containsAll(['ollama_local', 'droid']));
    // Cloud providers should NOT be present
    expect(ids.contains('openai'), isFalse);
    expect(ids.contains('anthropic'), isFalse);
  });
}
