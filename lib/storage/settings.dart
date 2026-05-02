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

  String _apiKeyKey(String providerId) => 'api_key:$providerId';
  String _baseUrlKey(String providerId) => 'base_url:$providerId';

  Future<String?> getApiKey(String providerId) =>
      _storage.read(key: _apiKeyKey(providerId));

  Future<void> setApiKey(String providerId, String value) =>
      _storage.write(key: _apiKeyKey(providerId), value: value);

  Future<void> clearApiKey(String providerId) =>
      _storage.delete(key: _apiKeyKey(providerId));

  Future<String?> getBaseUrlOverride(String providerId) =>
      _storage.read(key: _baseUrlKey(providerId));

  Future<void> setBaseUrlOverride(String providerId, String value) =>
      _storage.write(key: _baseUrlKey(providerId), value: value);
}
