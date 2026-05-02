import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('default Ollama URL is localhost:11434', () async {
    final repo = SettingsRepository();
    expect(await repo.getOllamaBaseUrl(), 'http://localhost:11434');
  });

  test('setOllamaBaseUrl roundtrips', () async {
    final repo = SettingsRepository();
    await repo.setOllamaBaseUrl('http://example.com:11434');
    expect(await repo.getOllamaBaseUrl(), 'http://example.com:11434');
  });

  test('per-provider api keys roundtrip', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    expect(await repo.getApiKey('opencode_zen'), isNull);
    await repo.setApiKey('opencode_zen', 'sk-zen-1');
    expect(await repo.getApiKey('opencode_zen'), 'sk-zen-1');
    await repo.clearApiKey('opencode_zen');
    expect(await repo.getApiKey('opencode_zen'), isNull);
  });

  test('ollama cloud key has its own slot', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    await repo.setApiKey('ollama_cloud', 'cloud-token');
    expect(await repo.getApiKey('ollama_cloud'), 'cloud-token');
  });

  test('base URL override roundtrips', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    expect(await repo.getBaseUrlOverride('ollama_cloud'), isNull);
    await repo.setBaseUrlOverride('ollama_cloud', 'https://my-ollama.example.com');
    expect(await repo.getBaseUrlOverride('ollama_cloud'), 'https://my-ollama.example.com');
  });
}
