import 'dart:io';

import 'package:path/path.dart' as p;

sealed class PrepareResult {
  const PrepareResult();
}

class PrepareOk extends PrepareResult {
  const PrepareOk();
}

class PrepareFailed extends PrepareResult {
  const PrepareFailed(this.stderr);
  final String stderr;
}

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

  Future<PrepareResult> prepare(Directory workDir, {bool isFlutter = false}) async {
    final exe = isFlutter ? 'flutter' : 'dart';
    final offline = await Process.run(
      exe,
      ['pub', 'get', '--offline'],
      workingDirectory: workDir.path,
    );
    if (offline.exitCode == 0) return const PrepareOk();

    final online = await Process.run(
      exe,
      ['pub', 'get'],
      workingDirectory: workDir.path,
    );
    if (online.exitCode == 0) return const PrepareOk();

    return PrepareFailed(
      online.stderr.toString().isEmpty
          ? offline.stderr.toString()
          : online.stderr.toString(),
    );
  }
}
