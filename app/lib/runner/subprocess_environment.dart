import 'dart:io';

import 'package:path/path.dart' as p;

Map<String, String> benchmarkSubprocessEnvironment({
  Map<String, String>? baseEnvironment,
  Iterable<String> additionalDeniedKeys = const [],
  Iterable<String> allowedSensitiveKeys = const [],
  bool allowReentrantFlutterTool = false,
  String? homeDirectory,
}) {
  final denied = {for (final key in additionalDeniedKeys) key.toUpperCase()};
  final allowedSensitive = {
    for (final key in allowedSensitiveKeys) key.toUpperCase(),
  };
  final source = baseEnvironment ?? Platform.environment;
  final sourceHome = source['HOME'] ?? source['USERPROFILE'];
  final environment = {
    for (final entry in source.entries)
      if (!_isSensitiveEnvironmentKey(entry.key, denied, allowedSensitive))
        entry.key: entry.value,
  };
  if (allowReentrantFlutterTool && !denied.contains('FLUTTER_ALREADY_LOCKED')) {
    environment['FLUTTER_ALREADY_LOCKED'] = 'true';
  }
  if (homeDirectory != null && homeDirectory.isNotEmpty) {
    if (!environment.containsKey('PUB_CACHE') &&
        sourceHome != null &&
        sourceHome.isNotEmpty) {
      environment['PUB_CACHE'] = p.join(sourceHome, '.pub-cache');
    }
    environment
      ..['HOME'] = homeDirectory
      ..['USERPROFILE'] = homeDirectory
      ..['XDG_CONFIG_HOME'] = p.join(homeDirectory, '.config')
      ..['XDG_CACHE_HOME'] = p.join(homeDirectory, '.cache')
      ..['ANALYZER_STATE_LOCATION_OVERRIDE'] = p.join(
        homeDirectory,
        '.dartServer',
      )
      ..['APPDATA'] = p.join(homeDirectory, 'AppData', 'Roaming')
      ..['LOCALAPPDATA'] = p.join(homeDirectory, 'AppData', 'Local');
  }
  return environment;
}

/// Builds the environment for agent-harness subprocesses using a strict
/// allowlist instead of the deny-list used for tool helpers.
///
/// Only baseline shell/locale/temp keys, Dart/Flutter tool keys, and keys the
/// harness explicitly allows via [allowedSensitiveKeys] (for example Droid
/// custom-model credentials or command-template agent API keys) reach the
/// harness. The result is additionally passed through the sensitive-key scrub
/// so an allowlisted pattern can never resurrect a denied credential.
Map<String, String> harnessSubprocessEnvironment({
  Map<String, String>? baseEnvironment,
  Iterable<String> additionalDeniedKeys = const [],
  Iterable<String> allowedSensitiveKeys = const [],
  String? homeDirectory,
}) {
  final source = baseEnvironment ?? Platform.environment;
  final allowedSensitive = {
    for (final key in allowedSensitiveKeys) key.toUpperCase(),
  };
  final allowlisted = {
    for (final entry in source.entries)
      if (_isAllowlistedHarnessEnvironmentKey(entry.key) ||
          allowedSensitive.contains(entry.key.toUpperCase()))
        entry.key: entry.value,
  };
  return benchmarkSubprocessEnvironment(
    baseEnvironment: allowlisted,
    additionalDeniedKeys: additionalDeniedKeys,
    allowedSensitiveKeys: allowedSensitiveKeys,
    homeDirectory: homeDirectory,
  );
}

const _harnessEnvironmentAllowlist = {
  'PATH',
  'HOME',
  'USERPROFILE',
  'USER',
  'LOGNAME',
  'SHELL',
  'TERM',
  'COLORTERM',
  'LANG',
  'LANGUAGE',
  'TZ',
  'TMPDIR',
  'TMP',
  'TEMP',
  'PWD',
  'PUB_CACHE',
  'ANALYZER_STATE_LOCATION_OVERRIDE',
  'FLUTTER_ROOT',
  'XDG_CONFIG_HOME',
  'XDG_CACHE_HOME',
  'XDG_DATA_HOME',
  'XDG_STATE_HOME',
  'XDG_RUNTIME_DIR',
  // Windows process/tool baseline.
  'APPDATA',
  'LOCALAPPDATA',
  'SYSTEMROOT',
  'SYSTEMDRIVE',
  'COMSPEC',
  'PATHEXT',
  'WINDIR',
};

const _harnessEnvironmentAllowlistPrefixes = ['LC_'];

bool _isAllowlistedHarnessEnvironmentKey(String key) {
  final normalized = key.toUpperCase();
  if (_harnessEnvironmentAllowlist.contains(normalized)) return true;
  return _harnessEnvironmentAllowlistPrefixes.any(normalized.startsWith);
}

bool _isSensitiveEnvironmentKey(
  String key,
  Set<String> additionalDeniedKeys,
  Set<String> allowedSensitiveKeys,
) {
  final normalized = key.toUpperCase();
  if (additionalDeniedKeys.contains(normalized)) return true;
  if (allowedSensitiveKeys.contains(normalized)) return false;
  if (normalized == 'AUTHORIZATION' ||
      normalized == 'COOKIE' ||
      normalized == 'SET_COOKIE' ||
      normalized == 'GITHUB_TOKEN' ||
      normalized == 'GH_TOKEN' ||
      normalized == 'SSH_AUTH_SOCK' ||
      normalized == 'SSH_AGENT_PID' ||
      normalized == 'SSH_ASKPASS' ||
      normalized == 'GPG_AGENT_INFO' ||
      normalized == 'GNUPGHOME' ||
      normalized == 'KRB5CCNAME' ||
      normalized == 'HTTP_PROXY' ||
      normalized == 'HTTPS_PROXY' ||
      normalized == 'ALL_PROXY' ||
      normalized == 'NO_PROXY' ||
      normalized == 'NETRC' ||
      normalized == 'KUBECONFIG' ||
      normalized == 'DOCKER_CONFIG' ||
      normalized == 'NPM_CONFIG_USERCONFIG' ||
      normalized == 'PIP_CONFIG_FILE' ||
      normalized == 'PIP_INDEX_URL' ||
      normalized == 'PIP_EXTRA_INDEX_URL' ||
      normalized == 'UV_INDEX_URL' ||
      normalized == 'UV_EXTRA_INDEX_URL' ||
      normalized == 'GIT_ASKPASS' ||
      normalized == 'GIT_SSH' ||
      normalized == 'GIT_SSH_COMMAND' ||
      normalized == 'GIT_CONFIG_GLOBAL' ||
      normalized == 'COMPOSER_AUTH') {
    return true;
  }
  if (normalized.startsWith('AWS_') ||
      normalized.startsWith('GOOGLE_APPLICATION_CREDENTIALS')) {
    return true;
  }
  return normalized.endsWith('_API_KEY') ||
      normalized.endsWith('_KEY') ||
      normalized.endsWith('_TOKEN') ||
      normalized.endsWith('_SECRET') ||
      normalized.endsWith('_PASSWORD') ||
      normalized.contains('API_KEY') ||
      normalized.contains('ACCESS_TOKEN') ||
      normalized.contains('AUTH_TOKEN') ||
      normalized.contains('CLIENT_SECRET');
}
