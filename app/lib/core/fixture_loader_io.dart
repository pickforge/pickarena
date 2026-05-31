import 'dart:io';

import 'package:path/path.dart' as p;

Future<Map<String, String>> loadFixtureFiles({
  required String assetRoot,
  required List<String> files,
  String? repoRoot,
}) async {
  final base = repoRoot == null
      ? Directory.current.path
      : p.normalize(p.absolute(repoRoot));
  final out = <String, String>{};
  for (final rel in files) {
    final file = File(p.join(base, assetRoot, rel));
    if (!await file.exists()) {
      throw FileSystemException('Fixture asset not found', file.path);
    }
    out[rel] = await file.readAsString();
  }
  return out;
}
