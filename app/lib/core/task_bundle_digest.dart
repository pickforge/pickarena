import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'task_bundle_inspection.dart';

const taskBundleDigestFileRoots = taskBundleInspectionFileRoots;

class CorpusManifestEntry {
  const CorpusManifestEntry({
    required this.taskId,
    required this.taskVersion,
    required this.taskBundleDigest,
  });

  final String taskId;
  final int taskVersion;
  final String taskBundleDigest;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'taskVersion': taskVersion,
    'taskBundleDigest': taskBundleDigest,
  };
}

String corpusManifestDigestSha256(Iterable<CorpusManifestEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final id = a.taskId.compareTo(b.taskId);
      if (id != 0) return id;
      final version = a.taskVersion.compareTo(b.taskVersion);
      if (version != 0) return version;
      return a.taskBundleDigest.compareTo(b.taskBundleDigest);
    });
  return sha256
      .convert(
        utf8.encode(
          sorted
              .map(
                (entry) =>
                    '${entry.taskId}\u0000${entry.taskVersion}\u0000${entry.taskBundleDigest}',
              )
              .join('\n'),
        ),
      )
      .toString();
}

Future<String> taskBundleDigestSha256(Directory bundleDirectory) async {
  final inspection = await TaskBundleInspection.inspect(bundleDirectory);
  return inspection.taskBundleDigestSha256();
}
