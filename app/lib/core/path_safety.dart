import 'dart:convert';

import 'package:crypto/crypto.dart';

final _unsafePathSegmentChars = RegExp(r'[^A-Za-z0-9._-]+');
final _unsafePathSegmentEdges = RegExp(r'^[._-]+|[._-]+$');

String safePathSegment(
  String value, {
  String prefix = 'segment',
  int maxStemChars = 48,
}) {
  if (maxStemChars <= 0) {
    throw ArgumentError.value(maxStemChars, 'maxStemChars');
  }
  final digest = sha256.convert(utf8.encode(value)).toString().substring(0, 12);
  final safePrefix = prefix
      .replaceAll(_unsafePathSegmentChars, '_')
      .replaceAll(_unsafePathSegmentEdges, '');
  final normalized = value
      .replaceAll(_unsafePathSegmentChars, '_')
      .replaceAll(_unsafePathSegmentEdges, '');
  final stem = normalized.isEmpty ? 'value' : normalized;
  final truncated = stem.length <= maxStemChars
      ? stem
      : stem.substring(0, maxStemChars);
  final safe = safePrefix.isEmpty ? 'segment' : safePrefix;
  return '${safe}_${truncated}_$digest';
}
