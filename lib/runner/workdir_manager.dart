import 'dart:io';

import 'package:path/path.dart' as p;

class WorkdirManager {
  WorkdirManager({required this.root});

  final Directory root;

  Future<Directory> createTaskWorkdir({
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
    required Map<String, String> fixtures,
    required String? generatedCode,
    required String generatedCodePath,
  }) async {
    final dir = Directory(
      p.join(root.path, 'runs', runId, providerId, modelId, taskId),
    );
    await dir.create(recursive: true);

    for (final entry in fixtures.entries) {
      final f = File(p.join(dir.path, entry.key));
      await f.parent.create(recursive: true);
      await f.writeAsString(entry.value);
    }

    if (generatedCode != null) {
      final f = File(p.join(dir.path, generatedCodePath));
      await f.parent.create(recursive: true);
      await f.writeAsString(generatedCode);
    }

    return dir;
  }
}
