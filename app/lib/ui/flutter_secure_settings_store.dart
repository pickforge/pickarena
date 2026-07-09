import 'dart:convert';

import 'package:dart_arena/storage/settings_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlutterSecureSettingsStore implements SettingsStore {
  FlutterSecureSettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ollamaBaseUrl = 'ollama_base_url';
  static const _judgeProviderId = 'judge_provider_id';
  static const _judgeModelId = 'judge_model_id';
  static const _evaluatorWeightsJson = 'evaluator_weights_json';
  static const _readmePath = 'readme_path';
  static const _reviewReviewerId = 'review_reviewer_id';
  static const _reviewReviewerAlias = 'review_reviewer_alias';

  static const _customLocalProvidersKey = 'custom_local_providers';

  static const _runConcurrency = 'run_concurrency';

  @override
  Future<int> getRunConcurrency() async {
    final raw = await _storage.read(key: _runConcurrency);
    final v = int.tryParse(raw ?? '');
    return (v ?? 4).clamp(1, 8).toInt();
  }

  @override
  Future<void> setRunConcurrency(int value) =>
      _storage.write(key: _runConcurrency, value: value.clamp(1, 8).toString());

  @override
  Future<String> getOllamaBaseUrl() async =>
      (await _storage.read(key: _ollamaBaseUrl)) ?? 'http://localhost:11434';

  @override
  Future<void> setOllamaBaseUrl(String value) =>
      _storage.write(key: _ollamaBaseUrl, value: value);

  String _apiKeyKey(String providerId) => 'api_key:$providerId';
  String _baseUrlKey(String providerId) => 'base_url:$providerId';

  @override
  Future<String?> getApiKey(String providerId) =>
      _storage.read(key: _apiKeyKey(providerId));

  @override
  Future<void> setApiKey(String providerId, String value) =>
      _storage.write(key: _apiKeyKey(providerId), value: value);

  @override
  Future<void> clearApiKey(String providerId) =>
      _storage.delete(key: _apiKeyKey(providerId));

  @override
  Future<List<CustomLocalProviderEntry>> getCustomLocalProviders() async {
    final raw = await _storage.read(key: _customLocalProvidersKey);
    if (raw == null) {
      final legacyUrl = await getBaseUrlOverride('local_openai');
      final legacyKey = await getApiKey('local_openai');
      final trimmedUrl = (legacyUrl ?? '').trim();
      final trimmedKey = (legacyKey ?? '').trim();
      if (trimmedUrl.isNotEmpty || trimmedKey.isNotEmpty) {
        if (trimmedUrl.isEmpty) {
          await setBaseUrlOverride('local_openai', 'http://127.0.0.1:8080/v1');
        } else if (trimmedUrl != legacyUrl) {
          await setBaseUrlOverride('local_openai', trimmedUrl);
        }
        final seed = [
          const CustomLocalProviderEntry(
            id: 'local_openai',
            name: 'Local OpenAI',
          ),
        ];
        await setCustomLocalProviders(seed);
        return seed;
      }
      return const [];
    }
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => CustomLocalProviderEntry.fromJson(e))
          .toList();
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> setCustomLocalProviders(
    List<CustomLocalProviderEntry> entries,
  ) async {
    final normalized = normalizeCustomLocalProviderEntries(entries);
    final json = jsonEncode(normalized.map((e) => e.toJson()).toList());
    await _storage.write(key: _customLocalProvidersKey, value: json);
  }

  @override
  Future<void> deleteCustomLocalProvider(String id) async {
    final list = await getCustomLocalProviders();
    final updated = list.where((e) => e.id != id).toList();
    if (updated.length != list.length) {
      await setCustomLocalProviders(updated);
    }
    await _storage.delete(key: _apiKeyKey(id));
    await _storage.delete(key: _baseUrlKey(id));
  }

  @override
  Future<String?> getBaseUrlOverride(String providerId) =>
      _storage.read(key: _baseUrlKey(providerId));

  @override
  Future<void> setBaseUrlOverride(String providerId, String value) =>
      _storage.write(key: _baseUrlKey(providerId), value: value);

  @override
  Future<String?> getJudgeProviderId() => _storage.read(key: _judgeProviderId);

  @override
  Future<void> setJudgeProviderId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _judgeProviderId);
    } else {
      await _storage.write(key: _judgeProviderId, value: id);
    }
  }

  @override
  Future<String?> getJudgeModelId() => _storage.read(key: _judgeModelId);

  @override
  Future<void> setJudgeModelId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _judgeModelId);
    } else {
      await _storage.write(key: _judgeModelId, value: id);
    }
  }

  @override
  Future<Map<String, double>> getEvaluatorWeights() async {
    final raw = await _storage.read(key: _evaluatorWeightsJson);
    if (raw == null || raw.isEmpty) {
      return effectiveEvaluatorWeightsFromJson(null);
    }
    return effectiveEvaluatorWeightsFromJson(jsonDecode(raw));
  }

  @override
  Future<void> setEvaluatorWeights(Map<String, double> overrides) =>
      _storage.write(key: _evaluatorWeightsJson, value: jsonEncode(overrides));

  @override
  Future<String?> getReadmePath() => _storage.read(key: _readmePath);

  @override
  Future<void> setReadmePath(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _readmePath);
    } else {
      await _storage.write(key: _readmePath, value: value);
    }
  }

  @override
  Future<String> getOrCreateReviewReviewerId() async {
    final existing = await _storage.read(key: _reviewReviewerId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = generateLocalReviewerId();
    await _storage.write(key: _reviewReviewerId, value: generated);
    return generated;
  }

  @override
  Future<String?> getReviewReviewerAlias() async {
    final raw = await _storage.read(key: _reviewReviewerAlias);
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> setReviewReviewerAlias(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _reviewReviewerAlias);
    } else {
      await _storage.write(key: _reviewReviewerAlias, value: trimmed);
    }
  }
}
