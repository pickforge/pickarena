import 'dart:convert';
import 'dart:math';

import 'package:dart_arena/core/scoring.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const customLocalProviderReservedIds = <String>{
  'ollama_local',
  'ollama_cloud',
  'opencode_go',
  'opencode_zen',
  'openai',
  'openrouter',
  'deepseek',
  'anthropic',
  'droid',
};

final customLocalProviderIdPattern = RegExp(r'^[a-z0-9_]{2,32}$');

class CustomLocalProviderEntry {
  const CustomLocalProviderEntry({
    required this.id,
    required this.name,
    this.extraHeaders = const {},
    this.defaultEfforts = const [],
  });

  final String id;
  final String name;
  final Map<String, String> extraHeaders;
  final List<String> defaultEfforts;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (extraHeaders.isNotEmpty) 'headers': extraHeaders,
    if (defaultEfforts.isNotEmpty) 'efforts': defaultEfforts,
  };

  factory CustomLocalProviderEntry.fromJson(Map<String, dynamic> j) {
    final headers = <String, String>{};
    final rawHeaders = j['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }
    final efforts = <String>[
      for (final effort in (j['efforts'] as List? ?? const <dynamic>[]))
        if (effort is String) effort,
    ];
    return CustomLocalProviderEntry(
      id: j['id'] as String,
      name: j['name'] as String,
      extraHeaders: headers,
      defaultEfforts: efforts,
    );
  }
}

String? validateCustomLocalProviderId(
  String id, {
  required Iterable<String> existingIds,
  String? currentId,
}) {
  final trimmed = id.trim();
  if (!customLocalProviderIdPattern.hasMatch(trimmed)) {
    return 'ID must be 2–32 characters: lowercase letters, digits, underscores';
  }
  if (customLocalProviderReservedIds.contains(trimmed)) return 'Reserved ID';
  for (final eid in existingIds) {
    if (eid == trimmed && eid != currentId) return 'ID already in use';
  }
  return null;
}

String? validateCustomLocalProviderEntry(
  CustomLocalProviderEntry entry, {
  required Iterable<String> existingIds,
}) {
  if (entry.name.trim().isEmpty) return 'Name is required';
  return validateCustomLocalProviderId(
    entry.id,
    existingIds: existingIds,
    currentId: entry.id,
  );
}

class SettingsRepository {
  SettingsRepository([FlutterSecureStorage? storage])
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

  Future<void> setCustomLocalProviders(
    List<CustomLocalProviderEntry> entries,
  ) async {
    final trimmed = entries.map((e) {
      final h = Map<String, String>.fromEntries(
        e.extraHeaders.entries.map(
          (kv) => MapEntry(kv.key.trim(), kv.value.trim()),
        ),
      );
      final eff = e.defaultEfforts
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      return CustomLocalProviderEntry(
        id: e.id.trim(),
        name: e.name.trim(),
        extraHeaders: h,
        defaultEfforts: eff,
      );
    }).toList();
    final ids = trimmed.map((e) => e.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('Duplicate IDs in provider list');
    }
    for (final e in trimmed) {
      if (e.name.isEmpty) throw ArgumentError('Name is required');
      final err = validateCustomLocalProviderId(
        e.id,
        existingIds: ids.where((id) => id != e.id),
      );
      if (err != null) throw ArgumentError(err);
    }
    final json = jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await _storage.write(key: _customLocalProvidersKey, value: json);
  }

  Future<void> deleteCustomLocalProvider(String id) async {
    final list = await getCustomLocalProviders();
    final updated = list.where((e) => e.id != id).toList();
    if (updated.length != list.length) {
      await setCustomLocalProviders(updated);
    }
    await _storage.delete(key: _apiKeyKey(id));
    await _storage.delete(key: _baseUrlKey(id));
  }

  Future<String?> getBaseUrlOverride(String providerId) =>
      _storage.read(key: _baseUrlKey(providerId));

  Future<void> setBaseUrlOverride(String providerId, String value) =>
      _storage.write(key: _baseUrlKey(providerId), value: value);

  Future<String?> getJudgeProviderId() => _storage.read(key: _judgeProviderId);

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
      _storage.write(key: _evaluatorWeightsJson, value: jsonEncode(overrides));

  Future<String?> getReadmePath() => _storage.read(key: _readmePath);

  Future<void> setReadmePath(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _readmePath);
    } else {
      await _storage.write(key: _readmePath, value: value);
    }
  }

  Future<String> getOrCreateReviewReviewerId() async {
    final existing = await _storage.read(key: _reviewReviewerId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateLocalReviewerId();
    await _storage.write(key: _reviewReviewerId, value: generated);
    return generated;
  }

  Future<String?> getReviewReviewerAlias() async {
    final raw = await _storage.read(key: _reviewReviewerAlias);
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> setReviewReviewerAlias(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _reviewReviewerAlias);
    } else {
      await _storage.write(key: _reviewReviewerAlias, value: trimmed);
    }
  }
}

String _generateLocalReviewerId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 'local-reviewer-$hex';
}
