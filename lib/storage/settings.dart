import 'dart:convert';

import 'package:dart_arena/core/scoring.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsRepository {
  SettingsRepository([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ollamaBaseUrl = 'ollama_base_url';
  static const _judgeProviderId = 'judge_provider_id';
  static const _judgeModelId = 'judge_model_id';
  static const _evaluatorWeightsJson = 'evaluator_weights_json';
  static const _readmePath = 'readme_path';

  static const _runConcurrency = 'run_concurrency';

  Future<int> getRunConcurrency() async {
    final raw = await _storage.read(key: _runConcurrency);
    final v = int.tryParse(raw ?? '');
    return v?.clamp(1, 8) ?? 4;
  }

  Future<void> setRunConcurrency(int value) =>
      _storage.write(key: _runConcurrency, value: value.clamp(1, 8).toString());

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

  Future<String?> getJudgeProviderId() =>
      _storage.read(key: _judgeProviderId);

  Future<void> setJudgeProviderId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _judgeProviderId);
    } else {
      await _storage.write(key: _judgeProviderId, value: id);
    }
  }

  Future<String?> getJudgeModelId() => _storage.read(key: _judgeModelId);

  Future<void> setJudgeModelId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _judgeModelId);
    } else {
      await _storage.write(key: _judgeModelId, value: id);
    }
  }

  Future<Map<String, double>> getEvaluatorWeights() async {
    final raw = await _storage.read(key: _evaluatorWeightsJson);
    final overrides = <String, double>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is num) overrides[entry.key] = v.toDouble();
      }
    }
    return {...defaultEvaluatorWeights, ...overrides};
  }

  Future<void> setEvaluatorWeights(Map<String, double> overrides) =>
      _storage.write(
        key: _evaluatorWeightsJson,
        value: jsonEncode(overrides),
      );

  Future<String?> getReadmePath() => _storage.read(key: _readmePath);

  Future<void> setReadmePath(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _readmePath);
    } else {
      await _storage.write(key: _readmePath, value: value);
    }
  }
}
