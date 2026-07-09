import 'dart:math';

import 'package:dart_arena/core/scoring.dart';

const dartArenaSettingsEnv = 'DART_ARENA_SETTINGS';
const dartArenaApiKeyEnvPrefix = 'DART_ARENA_API_KEY_';

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

abstract interface class SettingsStore {
  Future<int> getRunConcurrency();

  Future<void> setRunConcurrency(int value);

  Future<String> getOllamaBaseUrl();

  Future<void> setOllamaBaseUrl(String value);

  Future<String?> getApiKey(String providerId);

  Future<void> setApiKey(String providerId, String value);

  Future<void> clearApiKey(String providerId);

  Future<List<CustomLocalProviderEntry>> getCustomLocalProviders();

  Future<void> setCustomLocalProviders(List<CustomLocalProviderEntry> entries);

  Future<void> deleteCustomLocalProvider(String id);

  Future<String?> getBaseUrlOverride(String providerId);

  Future<void> setBaseUrlOverride(String providerId, String value);

  Future<String?> getJudgeProviderId();

  Future<void> setJudgeProviderId(String? id);

  Future<String?> getJudgeModelId();

  Future<void> setJudgeModelId(String? id);

  Future<Map<String, double>> getEvaluatorWeights();

  Future<void> setEvaluatorWeights(Map<String, double> overrides);

  Future<String?> getReadmePath();

  Future<void> setReadmePath(String? value);

  Future<String> getOrCreateReviewReviewerId();

  Future<String?> getReviewReviewerAlias();

  Future<void> setReviewReviewerAlias(String? value);
}

String? validateCustomLocalProviderId(
  String id, {
  required Iterable<String> existingIds,
  String? currentId,
}) {
  final trimmed = id.trim();
  if (!customLocalProviderIdPattern.hasMatch(trimmed)) {
    return 'ID must be 2-32 characters: lowercase letters, digits, underscores';
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

List<CustomLocalProviderEntry> normalizeCustomLocalProviderEntries(
  List<CustomLocalProviderEntry> entries,
) {
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
  return trimmed;
}

Map<String, double> effectiveEvaluatorWeightsFromJson(Object? raw) {
  final overrides = <String, double>{};
  if (raw is Map) {
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num) {
        overrides[key] = value.toDouble();
      }
    }
  }
  return {...defaultEvaluatorWeights, ...overrides};
}

String generateLocalReviewerId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 'local-reviewer-$hex';
}
