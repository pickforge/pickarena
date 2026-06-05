import 'dart:convert';

class ModelIdentity {
  const ModelIdentity({
    required this.providerId,
    required this.modelId,
    required this.baseModelId,
    this.effort,
    Map<String, Object?> modelConfig = const {},
  }) : _modelConfig = modelConfig;

  factory ModelIdentity.from({
    required String providerId,
    required String modelId,
    Map<String, Object?> additionalModelConfig = const {},
  }) {
    final separator = modelId.lastIndexOf('::');
    if (separator <= 0 || separator == modelId.length - 2) {
      return ModelIdentity(
        providerId: providerId,
        modelId: modelId,
        baseModelId: modelId,
        modelConfig: _normalizedModelConfig(additionalModelConfig),
      );
    }
    final effort = modelId.substring(separator + 2);
    return ModelIdentity(
      providerId: providerId,
      modelId: modelId,
      baseModelId: modelId.substring(0, separator),
      effort: effort,
      modelConfig: _normalizedModelConfig(
        additionalModelConfig,
        effort: effort,
      ),
    );
  }

  final String providerId;
  final String modelId;
  final String baseModelId;
  final String? effort;
  final Map<String, Object?> _modelConfig;

  Map<String, Object?> get modelConfigJson => _modelConfig;

  Map<String, Object?> get exportJson => {
    'baseModelId': baseModelId,
    'modelConfig': modelConfigJson,
  };
}

Map<String, Object?> modelIdentityExportJson({
  required String providerId,
  required String modelId,
  Map<String, Object?> additionalModelConfig = const {},
}) {
  return ModelIdentity.from(
    providerId: providerId,
    modelId: modelId,
    additionalModelConfig: additionalModelConfig,
  ).exportJson;
}

class ModelConfigIndex {
  const ModelConfigIndex._({
    required Map<String, Map<String, Object?>> configs,
    required Set<String> conflicts,
  }) : _configs = configs,
       _conflicts = conflicts;

  factory ModelConfigIndex.empty() =>
      const ModelConfigIndex._(configs: {}, conflicts: {});

  factory ModelConfigIndex.fromRunProvenanceJson(String? provenanceJson) {
    return ModelConfigIndex.fromRunProvenanceJsons([provenanceJson]);
  }

  factory ModelConfigIndex.fromRunProvenanceJsons(
    Iterable<String?> provenanceJsons,
  ) {
    final builder = _ModelConfigIndexBuilder();
    for (final provenanceJson in provenanceJsons) {
      if (provenanceJson == null || provenanceJson.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(provenanceJson);
        if (decoded is Map<String, Object?>) {
          builder.addRunProvenance(decoded);
        }
      } on FormatException {
        continue;
      }
    }
    return builder.build();
  }

  final Map<String, Map<String, Object?>> _configs;
  final Set<String> _conflicts;

  Map<String, Object?> modelConfigFor({
    required String providerId,
    required String modelId,
  }) {
    final key = _modelConfigKey(providerId, modelId);
    if (_conflicts.contains(key)) return const {};
    return _configs[key] ?? const {};
  }

  Map<String, Object?> exportJsonFor({
    required String providerId,
    required String modelId,
  }) {
    return modelIdentityExportJson(
      providerId: providerId,
      modelId: modelId,
      additionalModelConfig: modelConfigFor(
        providerId: providerId,
        modelId: modelId,
      ),
    );
  }

  List<String> get warningMessages {
    final sorted = _conflicts.toList()..sort();
    return [
      for (final key in sorted)
        'Model config metadata conflicts across source run provenance for ${_readableModelConfigKey(key)}.',
    ];
  }
}

Map<String, Object?> normalizeModelMetadataJson(Map<String, Object?> values) {
  return _normalizeJsonObject(values);
}

class _ModelConfigIndexBuilder {
  final _configs = <String, Map<String, Object?>>{};
  final _conflicts = <String>{};

  void addRunProvenance(Map<String, Object?> provenance) {
    final providers = provenance['providers'];
    if (providers is List) {
      for (final provider in providers) {
        if (provider is! Map) continue;
        final providerId = _nonEmptyString(provider['id']);
        if (providerId == null) continue;
        final selectedModelConfigs = provider['selectedModelConfigs'];
        if (selectedModelConfigs is! List) continue;
        for (final item in selectedModelConfigs) {
          if (item is! Map) continue;
          final modelId = _nonEmptyString(item['modelId']);
          if (modelId == null) continue;
          add(providerId, modelId, _configFromRow(item));
        }
      }
    }

    final combos = provenance['combos'];
    if (combos is List) {
      for (final combo in combos) {
        if (combo is! Map) continue;
        final providerId = _nonEmptyString(combo['providerId']);
        final modelId = _nonEmptyString(combo['modelId']);
        if (providerId == null || modelId == null) continue;
        add(providerId, modelId, _configFromRow(combo));
      }
    }
  }

  void add(String providerId, String modelId, Map<String, Object?> config) {
    if (config.isEmpty) return;
    final normalized = _normalizedModelConfig(config);
    final key = _modelConfigKey(providerId, modelId);
    final previous = _configs[key];
    if (previous == null) {
      _configs[key] = normalized;
      return;
    }
    if (!_jsonValueEquals(previous, normalized)) {
      _conflicts.add(key);
    }
  }

  ModelConfigIndex build() {
    return ModelConfigIndex._(
      configs: Map<String, Map<String, Object?>>.unmodifiable({
        for (final entry in _configs.entries)
          entry.key: Map<String, Object?>.unmodifiable(entry.value),
      }),
      conflicts: Set.unmodifiable(_conflicts),
    );
  }
}

Map<String, Object?> _configFromRow(Map<dynamic, dynamic> row) {
  final modelConfig = row['modelConfig'];
  if (modelConfig is! Map) return const {};
  return _normalizeJsonObject(modelConfig);
}

Map<String, Object?> _normalizedModelConfig(
  Map<String, Object?> values, {
  String? effort,
}) {
  final normalized = _normalizeJsonObject(values);
  if (effort == null) {
    normalized.remove('effort');
    return normalized;
  }
  normalized['effort'] = effort;
  return _normalizeJsonObject(normalized);
}

Map<String, Object?> _normalizeJsonObject(Map<dynamic, dynamic> values) {
  final keys = values.keys.map((key) => key.toString()).toList()..sort();
  final result = <String, Object?>{};
  for (final key in keys) {
    final value = _normalizeJsonValue(values[key]);
    if (value != null) result[key] = value;
  }
  return result;
}

Object? _normalizeJsonValue(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is bool) return value;
  if (value is num) return value.isFinite ? value : null;
  if (value is Map) return _normalizeJsonObject(value);
  if (value is Iterable) {
    final result = <Object?>[];
    for (final item in value) {
      final normalized = _normalizeJsonValue(item);
      if (normalized != null) result.add(normalized);
    }
    return result;
  }
  return null;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _modelConfigKey(String providerId, String modelId) {
  return '$providerId\u0000$modelId';
}

String _readableModelConfigKey(String key) {
  final parts = key.split('\u0000');
  if (parts.length != 2) return key;
  return '${parts[0]}:${parts[1]}';
}

bool _jsonValueEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key)) return false;
      if (!_jsonValueEquals(entry.value, right[entry.key])) return false;
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_jsonValueEquals(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}
