import 'dart:io';

Map<String, String> benchmarkSubprocessEnvironment({
  Map<String, String>? baseEnvironment,
  Iterable<String> additionalDeniedKeys = const [],
}) {
  final denied = {for (final key in additionalDeniedKeys) key.toUpperCase()};
  final source = baseEnvironment ?? Platform.environment;
  return {
    for (final entry in source.entries)
      if (!_isSensitiveEnvironmentKey(entry.key, denied))
        entry.key: entry.value,
  };
}

bool _isSensitiveEnvironmentKey(String key, Set<String> additionalDeniedKeys) {
  final normalized = key.toUpperCase();
  if (additionalDeniedKeys.contains(normalized)) return true;
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
      normalized == 'KRB5CCNAME') {
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
