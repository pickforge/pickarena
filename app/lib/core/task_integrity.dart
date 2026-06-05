import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/benchmark_task.dart';

Map<String, String> hiddenVerifierDigests(BenchmarkTask task) {
  final entries = task.hiddenVerifiers.toList()
    ..sort((a, b) {
      final idCompare = a.id.compareTo(b.id);
      if (idCompare != 0) return idCompare;
      return a.testPath.compareTo(b.testPath);
    });
  return {
    for (final verifier in entries)
      verifier.id: _sha256(
        jsonEncode({
          'id': verifier.id,
          'testPath': verifier.testPath,
          'files': _fileDigests(verifier.files),
        }),
      ),
  };
}

Map<String, String> _fileDigests(Map<String, String> files) {
  final entries = files.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return {for (final entry in entries) entry.key: _sha256(entry.value)};
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
