import 'dart:convert';
import 'dart:io';

Map<String, dynamic>? readFactorySettings() {
  try {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) return null;
    final file = File('$home/.factory/settings.json');
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, dynamic> ? decoded : null;
  } on Object {
    return null;
  }
}

Set<String> factoryCustomModelEnvironmentReferences(
  String modelId, {
  Map<String, dynamic>? settings,
}) {
  final resolvedSettings = settings ?? readFactorySettings();
  final customModels = resolvedSettings?['customModels'];
  if (customModels is! List) return const {};
  for (final item in customModels) {
    if (item is! Map) continue;
    final id = item['id'];
    final model = item['model'];
    if (id != modelId && model != modelId) continue;
    return Set.unmodifiable(_environmentReferences(item));
  }
  return const {};
}

Map<String, Object?> factoryCustomModelRuntimeConfig(
  String modelId, {
  Map<String, dynamic>? settings,
}) {
  final selected = _selectedCustomModel(modelId, settings: settings);
  if (selected == null) return const {};

  final id = _nonEmptyString(selected['id']);
  final model = _nonEmptyString(selected['model']);
  final provider = _nonEmptyString(selected['provider']);
  final displayName = _nonEmptyString(selected['displayName']);
  final maxOutputTokens = _positiveInt(selected['maxOutputTokens']);
  final maxContextLimit = _positiveInt(selected['maxContextLimit']);
  final noImageSupport = selected['noImageSupport'];

  return {
    'factoryCustomModel': true,
    if (id != null) 'factoryCustomModelId': id,
    if (model != null) 'configuredModelSnapshot': model,
    if (provider != null) 'customModelProvider': provider,
    if (displayName != null) 'customModelDisplayName': displayName,
    if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
    if (maxContextLimit != null) 'maxContextTokens': maxContextLimit,
    if (noImageSupport is bool) 'imageInputSupported': !noImageSupport,
  };
}

Map<dynamic, dynamic>? _selectedCustomModel(
  String modelId, {
  Map<String, dynamic>? settings,
}) {
  final resolvedSettings = settings ?? readFactorySettings();
  final customModels = resolvedSettings?['customModels'];
  if (customModels is! List) return null;
  for (final item in customModels) {
    if (item is! Map) continue;
    final id = item['id'];
    final model = item['model'];
    if (id == modelId || model == modelId) return item;
  }
  return null;
}

Set<String> _environmentReferences(Object? value) {
  final references = <String>{};
  void visit(Object? current) {
    if (current is String) {
      for (final match in _environmentReferencePattern.allMatches(current)) {
        final key = match.group(1) ?? match.group(2);
        if (key != null && key.isNotEmpty) references.add(key);
      }
    } else if (current is Map) {
      for (final entry in current.entries) {
        visit(entry.value);
      }
    } else if (current is Iterable) {
      for (final item in current) {
        visit(item);
      }
    }
  }

  visit(value);
  return references;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _positiveInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value.isFinite && value > 0) return value.round();
  return null;
}

final _environmentReferencePattern = RegExp(
  r'\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))',
);
