class BundleWarning {
  const BundleWarning({
    required this.code,
    required this.message,
    this.taskRunId,
    this.path,
  });

  final String code;
  final String message;
  final String? taskRunId;
  final String? path;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    if (taskRunId != null) 'taskRunId': taskRunId,
    if (path != null) 'path': path,
  };
}

class ArtifactDescriptor {
  const ArtifactDescriptor({
    required this.artifactId,
    required this.kind,
    required this.taskRunId,
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final String artifactId;
  final String kind;
  final String taskRunId;
  final String path;
  final int bytes;
  final String sha256;

  Map<String, Object?> toJson() => {
    'artifactId': artifactId,
    'kind': kind,
    'taskRunId': taskRunId,
    'path': path,
    'bytes': bytes,
    'sha256': sha256,
  };
}

class RunManifestV1 {
  const RunManifestV1({
    required this.generatedAt,
    required this.run,
    required this.appVersion,
    required this.driftSchemaVersion,
    required this.exportTool,
    required this.environment,
    required this.taskRuns,
    required this.counts,
    required this.evaluatorIds,
    required this.passSummary,
    required this.failureSummary,
    required this.artifacts,
    required this.checksumsPath,
    required this.warnings,
    this.provenance,
  });

  final String generatedAt;
  final Map<String, Object?> run;
  final String appVersion;
  final int driftSchemaVersion;
  final Map<String, Object?> exportTool;
  final Map<String, Object?> environment;
  final List<Map<String, Object?>> taskRuns;
  final Map<String, Object?> counts;
  final List<String> evaluatorIds;
  final Map<String, Object?> passSummary;
  final Map<String, int> failureSummary;
  final List<ArtifactDescriptor> artifacts;
  final String checksumsPath;
  final List<BundleWarning> warnings;
  final Object? provenance;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'generatedAt': generatedAt,
    'run': run,
    'appVersion': appVersion,
    'driftSchemaVersion': driftSchemaVersion,
    'exportTool': exportTool,
    'environment': environment,
    'taskRuns': taskRuns,
    'counts': counts,
    'evaluatorIds': evaluatorIds,
    'passSummary': passSummary,
    'failureSummary': failureSummary,
    'artifacts': [for (final artifact in artifacts) artifact.toJson()],
    'checksumsPath': checksumsPath,
    'warnings': [for (final warning in warnings) warning.toJson()],
    if (provenance != null) 'provenance': provenance,
  };
}
