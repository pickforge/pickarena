import 'dart:io';

import 'package:path/path.dart' as p;

Future<String> loadPlanMarkdown({
  required String assetPath,
  String? repoRoot,
}) async {
  final base = repoRoot == null
      ? Directory.current.path
      : p.normalize(p.absolute(repoRoot));
  final file = File(p.join(base, assetPath));
  if (!await file.exists()) {
    throw FileSystemException('Reference plan asset not found', file.path);
  }
  return file.readAsString();
}
