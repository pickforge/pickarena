import 'dart:io';

import 'package:dart_arena/core/workspace_path.dart';

sealed class ReferenceSolution {
  const ReferenceSolution();
}

class ReferenceFileSolution extends ReferenceSolution {
  const ReferenceFileSolution(this.files);

  final Map<String, String> files;
}

class ReferencePatchSolution extends ReferenceSolution {
  const ReferencePatchSolution(this.patch);

  final String patch;
}

Future<void> applyReferenceSolution(
  Directory workDir,
  ReferenceSolution solution,
) async {
  switch (solution) {
    case ReferenceFileSolution(:final files):
      final resolved = [
        for (final entry in files.entries)
          MapEntry(resolveWorkspaceFile(workDir, entry.key), entry.value),
      ];
      for (final entry in resolved) {
        await entry.key.parent.create(recursive: true);
        await entry.key.writeAsString(entry.value);
      }
    case ReferencePatchSolution():
      // TODO: implement patch-based reference solutions in Phase 2.
      throw UnsupportedError(
        'Patch-based reference solutions are not supported in Phase 1.',
      );
  }
}
