import 'dart:convert';

import 'package:crypto/crypto.dart';

String? environmentCompatibilityKey(Map<String, Object?> environment) {
  final dartVersion = _sdkVersion(environment['dartVersion']);
  final flutterVersion = _sdkVersion(environment['flutterVersion']);
  final hostPlatform = _nonEmptyString(
    environment['hostPlatform'],
  )?.toLowerCase();
  final lockDigest = _dependencyLockDigest(environment)?.toLowerCase();
  if (dartVersion == null &&
      flutterVersion == null &&
      hostPlatform == null &&
      lockDigest == null) {
    return null;
  }

  return jsonEncode({
    'dartVersion': dartVersion,
    'flutterVersion': flutterVersion,
    'hostPlatform': hostPlatform,
    'pubspecLockSha256': lockDigest,
  });
}

String? environmentCompatibilityId(Map<String, Object?> environment) {
  final key = environmentCompatibilityKey(environment);
  if (key == null) return null;
  return sha256.convert(utf8.encode(key)).toString().substring(0, 12);
}

String? environmentSdkVersion(Object? value) => _sdkVersion(value);

String? _sdkVersion(Object? value) {
  final version = _nonEmptyString(value);
  if (version == null || version == 'unknown') return null;
  return version.split(RegExp(r'\s+')).first;
}

String? _dependencyLockDigest(Map<String, Object?> environment) {
  final snapshot = _objectMap(environment['dependencySnapshot']);
  final files = _objectMap(snapshot['files']);
  final lockfile = _objectMap(files['pubspec.lock']);
  return _nonEmptyString(lockfile['sha256']);
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const {};
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
