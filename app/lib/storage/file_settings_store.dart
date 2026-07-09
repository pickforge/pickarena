import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/storage/settings_store.dart';
import 'package:path/path.dart' as p;

/// Stores CLI/test settings in a JSON file.
///
/// If `apiKeyEnv` or `DART_ARENA_API_KEY_<PROVIDER_ID>` supplies a provider
/// key, reads use the environment value and writes strip that provider's
/// `apiKey` from disk.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore({
    String? path,
    Map<String, String>? environment,
    Future<File> Function(File file, String newPath)? renameFile,
    bool replaceWithBackup = false,
  }) : this._(
         _resolveSettingsPath(path, environment ?? Platform.environment),
         environment ?? Platform.environment,
         renameFile,
         replaceWithBackup,
       );

  FileSettingsStore._(
    _ResolvedSettingsPath resolved,
    Map<String, String> environment,
    this._renameFile,
    this._replaceWithBackup,
  ) : _environment = Map.unmodifiable(environment),
      _file = File(resolved.path),
      _chmodParentWhenCreated = resolved.chmodParentWhenCreated;

  final Map<String, String> _environment;
  final File _file;
  final bool _chmodParentWhenCreated;
  final Future<File> Function(File file, String newPath)? _renameFile;
  final bool _replaceWithBackup;
  Future<void> _updateQueue = Future.value();

  String get path => _file.path;

  static String defaultSettingsPath(Map<String, String> environment) {
    final home = _homeDirectory(environment);
    if (home != null && home.isNotEmpty) {
      return p.join(home, '.dart_arena', 'settings.json');
    }
    return p.join(Directory.current.path, '.dart_arena_settings.json');
  }

  @override
  Future<int> getRunConcurrency() async {
    final settings = await _readSettings();
    final value = _readInt(settings['runConcurrency']);
    return (value ?? 4).clamp(1, 8).toInt();
  }

  @override
  Future<void> setRunConcurrency(int value) async {
    await _updateSettings((settings) {
      settings['runConcurrency'] = value.clamp(1, 8).toInt();
    });
  }

  @override
  Future<String> getOllamaBaseUrl() async {
    final settings = await _readSettings();
    return _readString(settings['ollamaBaseUrl']) ?? 'http://localhost:11434';
  }

  @override
  Future<void> setOllamaBaseUrl(String value) async {
    await _updateSettings((settings) {
      settings['ollamaBaseUrl'] = value;
    });
  }

  @override
  Future<String?> getApiKey(String providerId) async {
    final settings = await _readSettings();
    final provider = _readProvider(settings, providerId);
    final envValue = _apiKeyFromEnvironment(providerId, provider);
    if (envValue != null) return envValue;
    return _readString(provider['apiKey']);
  }

  @override
  Future<void> setApiKey(String providerId, String value) async {
    await _updateProvider(providerId, (provider) {
      if (_apiKeyFromEnvironment(providerId, provider) != null) {
        provider.remove('apiKey');
      } else {
        provider['apiKey'] = value;
      }
    });
  }

  @override
  Future<void> clearApiKey(String providerId) async {
    await _updateProvider(providerId, (provider) {
      provider.remove('apiKey');
    });
  }

  @override
  Future<List<CustomLocalProviderEntry>> getCustomLocalProviders() async {
    final settings = await _readSettings();
    final raw = settings['customLocalProviders'];
    if (raw == null) {
      final providers = _readObject(settings['providers']);
      final legacy = _readObject(providers['local_openai']);
      final legacyUrl = _readString(legacy['baseUrl']);
      final legacyKey =
          _apiKeyFromEnvironment('local_openai', legacy) ??
          _readString(legacy['apiKey']);
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
      return (raw as List)
          .whereType<Map<Object?, Object?>>()
          .map((e) => CustomLocalProviderEntry.fromJson(Map.from(e)))
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
    await _updateSettings((settings) {
      settings['customLocalProviders'] = [
        for (final entry in normalized) entry.toJson(),
      ];
    });
  }

  @override
  Future<void> deleteCustomLocalProvider(String id) async {
    final list = await getCustomLocalProviders();
    final updated = list.where((e) => e.id != id).toList();
    if (updated.length != list.length) {
      await setCustomLocalProviders(updated);
    }
    await _updateProvider(id, (provider) {
      provider.remove('apiKey');
      provider.remove('apiKeyEnv');
      provider.remove('baseUrl');
    });
  }

  @override
  Future<String?> getBaseUrlOverride(String providerId) async {
    final settings = await _readSettings();
    return _readString(_readProvider(settings, providerId)['baseUrl']);
  }

  @override
  Future<void> setBaseUrlOverride(String providerId, String value) async {
    await _updateProvider(providerId, (provider) {
      provider['baseUrl'] = value;
    });
  }

  @override
  Future<String?> getJudgeProviderId() async {
    final settings = await _readSettings();
    return _readString(_readObject(settings['judge'])['providerId']);
  }

  @override
  Future<void> setJudgeProviderId(String? id) async {
    await _updateNestedObject('judge', (judge) {
      if (id == null) {
        judge.remove('providerId');
      } else {
        judge['providerId'] = id;
      }
    });
  }

  @override
  Future<String?> getJudgeModelId() async {
    final settings = await _readSettings();
    return _readString(_readObject(settings['judge'])['modelId']);
  }

  @override
  Future<void> setJudgeModelId(String? id) async {
    await _updateNestedObject('judge', (judge) {
      if (id == null) {
        judge.remove('modelId');
      } else {
        judge['modelId'] = id;
      }
    });
  }

  @override
  Future<Map<String, double>> getEvaluatorWeights() async {
    final settings = await _readSettings();
    return effectiveEvaluatorWeightsFromJson(settings['evaluatorWeights']);
  }

  @override
  Future<void> setEvaluatorWeights(Map<String, double> overrides) async {
    await _updateSettings((settings) {
      settings['evaluatorWeights'] = overrides;
    });
  }

  @override
  Future<String?> getReadmePath() async {
    final settings = await _readSettings();
    return _readString(settings['readmePath']);
  }

  @override
  Future<void> setReadmePath(String? value) async {
    await _updateSettings((settings) {
      if (value == null || value.isEmpty) {
        settings.remove('readmePath');
      } else {
        settings['readmePath'] = value;
      }
    });
  }

  @override
  Future<String> getOrCreateReviewReviewerId() async {
    final settings = await _readSettings();
    final reviewer = _readObject(settings['reviewer']);
    final existing = _readString(reviewer['id']);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = generateLocalReviewerId();
    await _updateNestedObject('reviewer', (reviewer) {
      reviewer['id'] = generated;
    });
    return generated;
  }

  @override
  Future<String?> getReviewReviewerAlias() async {
    final settings = await _readSettings();
    final raw = _readString(_readObject(settings['reviewer'])['alias']);
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> setReviewReviewerAlias(String? value) async {
    await _updateNestedObject('reviewer', (reviewer) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        reviewer.remove('alias');
      } else {
        reviewer['alias'] = trimmed;
      }
    });
  }

  Future<Map<String, Object?>> _readSettings() async {
    if (!await _file.exists()) return {};
    final raw = await _file.readAsString();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return {};
  }

  Future<void> _updateSettings(
    void Function(Map<String, Object?> settings) update,
  ) async {
    await _withUpdateLock(() async {
      final settings = await _readSettings();
      update(settings);
      await _writeSettings(settings);
    });
  }

  Future<void> _writeSettings(Map<String, Object?> settings) async {
    _stripEnvironmentBackedApiKeys(settings);
    await _ensureSettingsParent();
    final temp = await _createPrivateTempFile();
    try {
      await temp.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(settings)}\n',
        flush: true,
      );
      await _replaceSettingsFile(temp);
      await _chmod(_file, '600');
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  Future<T> _withUpdateLock<T>(Future<T> Function() action) {
    final run = _updateQueue.then((_) => action(), onError: (_) => action());
    _updateQueue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _ensureSettingsParent() async {
    final parent = _file.parent;
    final existed = await parent.exists();
    await parent.create(recursive: true);
    if (_chmodParentWhenCreated && !existed) {
      await _chmod(parent, '700');
    }
  }

  Future<File> _createPrivateTempFile() async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final temp = _siblingFile('tmp', attempt);
      try {
        await temp.create(exclusive: true);
        await _chmod(temp, '600');
        return temp;
      } on PathExistsException {
        continue;
      }
    }
    throw FileSystemException('Unable to create temporary settings file', path);
  }

  Future<File> _createBackupFile() async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final backup = _siblingFile('bak', attempt);
      if (!await backup.exists()) return backup;
    }
    throw FileSystemException('Unable to create backup settings file', path);
  }

  File _siblingFile(String extension, int attempt) {
    final basename = p.basename(_file.path);
    return File(
      p.join(
        _file.parent.path,
        '.$basename.${DateTime.now().microsecondsSinceEpoch}.$attempt.$extension',
      ),
    );
  }

  Future<void> _replaceSettingsFile(File temp) async {
    if (!Platform.isWindows && !_replaceWithBackup) {
      await _rename(temp, _file.path);
      return;
    }

    File? backup;
    if (await _file.exists()) {
      backup = await _createBackupFile();
      await _rename(_file, backup.path);
    }
    try {
      await _rename(temp, _file.path);
    } on Object {
      if (backup != null && await backup.exists()) {
        if (await _file.exists()) {
          await _file.delete();
        }
        await _rename(backup, _file.path);
      }
      rethrow;
    }
    if (backup != null && await backup.exists()) {
      await backup.delete();
    }
  }

  Future<File> _rename(File file, String newPath) {
    final rename = _renameFile;
    if (rename != null) return rename(file, newPath);
    return file.rename(newPath);
  }

  Future<void> _chmod(FileSystemEntity entity, String mode) async {
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', [mode, entity.path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Unable to chmod ${entity.path}: ${result.stderr}',
        entity.path,
      );
    }
  }

  String? _apiKeyFromEnvironment(
    String providerId,
    Map<String, Object?> provider,
  ) {
    final envNames = [
      _readString(provider['apiKeyEnv']),
      _providerApiKeyEnvName(providerId),
    ].whereType<String>();
    for (final envName in envNames) {
      final value = _environment[envName];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void _stripEnvironmentBackedApiKeys(Map<String, Object?> settings) {
    final providers = _readObject(settings['providers']);
    if (providers.isEmpty) return;
    var changed = false;
    for (final entry in providers.entries.toList()) {
      final providerId = entry.key;
      final provider = _readObject(entry.value);
      if (_apiKeyFromEnvironment(providerId, provider) != null) {
        provider.remove('apiKey');
        changed = true;
      }
      if (provider.isEmpty) {
        providers.remove(providerId);
      } else {
        providers[providerId] = provider;
      }
    }
    if (providers.isEmpty) {
      settings.remove('providers');
    } else if (changed) {
      settings['providers'] = providers;
    }
  }

  Future<void> _updateNestedObject(
    String key,
    void Function(Map<String, Object?> object) update,
  ) async {
    await _updateSettings((settings) {
      final object = _readObject(settings[key]);
      update(object);
      if (object.isEmpty) {
        settings.remove(key);
      } else {
        settings[key] = object;
      }
    });
  }

  Map<String, Object?> _readProvider(
    Map<String, Object?> settings,
    String providerId,
  ) {
    return _readObject(_readObject(settings['providers'])[providerId]);
  }

  Future<void> _updateProvider(
    String providerId,
    void Function(Map<String, Object?> provider) update,
  ) async {
    await _updateSettings((settings) {
      final providers = _readObject(settings['providers']);
      final provider = _readObject(providers[providerId]);
      update(provider);
      if (provider.isEmpty) {
        providers.remove(providerId);
      } else {
        providers[providerId] = provider;
      }
      if (providers.isEmpty) {
        settings.remove('providers');
      } else {
        settings['providers'] = providers;
      }
    });
  }
}

Map<String, Object?> _readObject(Object? raw) {
  if (raw is Map) return Map<String, Object?>.from(raw);
  return {};
}

String? _readString(Object? raw) => raw is String ? raw : null;

int? _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is String) return int.tryParse(raw);
  return null;
}

String _providerApiKeyEnvName(String providerId) {
  final suffix = providerId
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return '$dartArenaApiKeyEnvPrefix$suffix';
}

String? _homeDirectory(Map<String, String> environment) {
  return environment['HOME'] ?? environment['USERPROFILE'];
}

_ResolvedSettingsPath _resolveSettingsPath(
  String? path,
  Map<String, String> environment,
) {
  if (path != null) return _ResolvedSettingsPath(path, false);
  final environmentPath = environment[dartArenaSettingsEnv];
  if (environmentPath != null) {
    return _ResolvedSettingsPath(environmentPath, false);
  }
  final defaultPath = FileSettingsStore.defaultSettingsPath(environment);
  final home = _homeDirectory(environment);
  return _ResolvedSettingsPath(defaultPath, home != null && home.isNotEmpty);
}

class _ResolvedSettingsPath {
  const _ResolvedSettingsPath(this.path, this.chmodParentWhenCreated);

  final String path;
  final bool chmodParentWhenCreated;
}
