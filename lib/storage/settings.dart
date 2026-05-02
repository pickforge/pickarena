import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsRepository {
  SettingsRepository([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ollamaBaseUrl = 'ollama_base_url';

  Future<String> getOllamaBaseUrl() async =>
      (await _storage.read(key: _ollamaBaseUrl)) ?? 'http://localhost:11434';

  Future<void> setOllamaBaseUrl(String value) =>
      _storage.write(key: _ollamaBaseUrl, value: value);
}
