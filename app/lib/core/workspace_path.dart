import 'dart:io';

import 'package:path/path.dart' as p;

File resolveWorkspaceFile(Directory workDir, String relativePath) {
  final normalized = p.normalize(relativePath);
  if (normalized == '.' ||
      p.isAbsolute(relativePath) ||
      p.split(normalized).contains('..')) {
    throw ArgumentError.value(
      relativePath,
      'relativePath',
      'must be a workspace-relative file path',
    );
  }

  final root = p.normalize(p.absolute(workDir.path));
  final resolved = p.normalize(p.join(root, normalized));
  if (!p.isWithin(root, resolved)) {
    throw ArgumentError.value(
      relativePath,
      'relativePath',
      'must resolve inside the workspace',
    );
  }

  return File(resolved);
}
