import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/task_bundle_digest.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:dart_arena/runner/task_qa_runner.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:path/path.dart' as p;

typedef TaskQaCliLineWriter = void Function(String line);
typedef TaskQaCliTaskRegistryBuilder = TaskRegistry Function();
typedef TaskQaCliEnvironmentProviderBuilder =
    RunProvenanceEnvironmentProvider Function();
typedef TaskQaCliGeneratedCodeSandboxBuilder =
    Future<GeneratedCodeSandbox?> Function(bool generatedCodeSandboxRequired);

class TaskQaCliDependencies {
  const TaskQaCliDependencies({
    this.taskRegistryBuilder = _emptyTaskRegistry,
    this.environmentProviderBuilder = _defaultEnvironmentProvider,
    this.generatedCodeSandboxBuilder = _defaultGeneratedCodeSandboxBuilder,
    this.now = _now,
  });

  final TaskQaCliTaskRegistryBuilder taskRegistryBuilder;
  final TaskQaCliEnvironmentProviderBuilder environmentProviderBuilder;
  final TaskQaCliGeneratedCodeSandboxBuilder generatedCodeSandboxBuilder;
  final DateTime Function() now;
}

TaskRegistry _emptyTaskRegistry() => TaskRegistry();

class TaskQaCliException implements Exception {
  const TaskQaCliException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<int> runTaskQaCli(
  List<String> args, {
  TaskQaCliDependencies dependencies = const TaskQaCliDependencies(),
  TaskQaCliLineWriter? stdoutWriter,
  TaskQaCliLineWriter? stderrWriter,
}) async {
  final out = stdoutWriter ?? stdout.writeln;
  final err = stderrWriter ?? stderr.writeln;

  try {
    final parsed = _parseArgs(args);
    if (parsed == null) {
      out(jsonEncode(_helpJson()));
      return 0;
    }
    final generatedCodeSandbox = await dependencies.generatedCodeSandboxBuilder(
      parsed.generatedCodeSandboxRequired,
    );
    if (parsed.generatedCodeSandboxRequired && generatedCodeSandbox == null) {
      throw const TaskQaCliException(
        'Generated-code sandbox is required, but no sandbox backend was configured.',
      );
    }

    final registry = dependencies.taskRegistryBuilder();
    final loadedBundleTaskIds = await _registerFileBackedTasks(
      registry,
      parsed.taskBundleRoots,
    );
    final tasks = _resolveTasks(
      registry,
      explicitTaskIds: parsed.taskIds,
      loadedBundleTaskIds: loadedBundleTaskIds,
    );
    final generatedAt = dependencies.now().toUtc();
    final outputDir = Directory(parsed.outputDir);
    final workdirRoot = Directory(parsed.workdirRoot);
    await outputDir.create(recursive: true);
    if (await workdirRoot.exists()) {
      await workdirRoot.delete(recursive: true);
    }
    await workdirRoot.create(recursive: true);

    final runner = TaskQaRunner(
      workdirManager: WorkdirManager(root: workdirRoot),
      requiredHiddenFlakeRuns: parsed.hiddenFlakeRuns,
      requireNegativeCases: true,
      evaluatorTimeout: parsed.evaluatorTimeout,
      generatedCodeSandboxRequired: parsed.generatedCodeSandboxRequired,
      generatedCodeSandbox: generatedCodeSandbox,
    );
    final environment = await dependencies
        .environmentProviderBuilder()
        .capture();
    final taskSummaries = <Map<String, Object?>>[];
    var rejectedTaskCount = 0;

    for (final task in tasks) {
      final report = await runner.run(task);
      final admitted = taskQaAdmissionReleaseGradePassed(report, environment);
      final failureMessages = taskQaAdmissionFailureMessages(
        report,
        environment,
      );
      if (!admitted) rejectedTaskCount++;
      final reportFile = await _writeTaskReport(
        outputDir: outputDir,
        task: task,
        report: report,
        generatedAt: generatedAt,
        environment: environment,
      );
      taskSummaries.add({
        'taskId': task.id,
        'taskVersion': task.version,
        'track': task.track.name,
        'status': admitted ? 'admitted' : 'rejected',
        'failureCount': failureMessages.length,
        'reportPath': _relativeOutputPath(outputDir, reportFile),
        'runtimeIsolation': {
          'generatedCodeSandboxEnforced':
              report.runtimeIsolation.generatedCodeSandboxEnforced,
          'workspaceEvidenceCount': report.runtimeIsolation.workspaceCount,
          'workspaceManifestSha256':
              report.runtimeIsolation.combinedVisibleManifestSha256,
          'restrictedPathCount': report.runtimeIsolation.restrictedPathCount,
        },
      });
    }

    final summaryFile = File(p.join(outputDir.path, 'admission_summary.json'));
    final status = rejectedTaskCount == 0 ? 'completed' : 'failed';
    final summary = {
      'schemaVersion': 1,
      'status': status,
      'generatedAt': generatedAt.toIso8601String(),
      'taskCount': tasks.length,
      'admittedTaskCount': tasks.length - rejectedTaskCount,
      'rejectedTaskCount': rejectedTaskCount,
      'generatedCodeSandbox': {
        'required': parsed.generatedCodeSandboxRequired,
        'enforced': generatedCodeSandbox != null,
        'backend':
            generatedCodeSandbox?.backend ??
            bubblewrapGeneratedCodeSandboxBackend,
      },
      'reports': taskSummaries,
    };
    await summaryFile.writeAsString(_prettyJson(summary));

    final line = jsonEncode({
      'status': status,
      'taskCount': tasks.length,
      'admittedTaskCount': tasks.length - rejectedTaskCount,
      'rejectedTaskCount': rejectedTaskCount,
      'admissionSummaryPath': p.normalize(p.absolute(summaryFile.path)),
    });
    if (rejectedTaskCount == 0) {
      out(line);
      return 0;
    }
    err(line);
    return 1;
  } on Object catch (error) {
    err(jsonEncode({'status': 'failed', 'error': error.toString()}));
    return 1;
  }
}

Future<List<String>> _registerFileBackedTasks(
  TaskRegistry registry,
  List<String> taskBundleRoots,
) async {
  final loadedTaskIds = <String>[];
  for (final root in taskBundleRoots) {
    final tasks = await loadFileBackedTasks(Directory(root));
    for (final task in tasks) {
      registry.register(task);
      loadedTaskIds.add(task.id);
    }
  }
  return loadedTaskIds;
}

List<BenchmarkTask> _resolveTasks(
  TaskRegistry registry, {
  required List<String> explicitTaskIds,
  required List<String> loadedBundleTaskIds,
}) {
  final taskIds = explicitTaskIds.isEmpty
      ? loadedBundleTaskIds
      : explicitTaskIds;
  if (taskIds.isEmpty) {
    throw const TaskQaCliException('no tasks selected');
  }
  return [for (final taskId in taskIds) _resolveTask(registry, taskId)];
}

BenchmarkTask _resolveTask(TaskRegistry registry, String taskId) {
  final task = registry.byId(taskId);
  if (task == null) throw TaskQaCliException('unknown task id: $taskId');
  return task;
}

Future<File> _writeTaskReport({
  required Directory outputDir,
  required BenchmarkTask task,
  required TaskQaReport report,
  required DateTime generatedAt,
  required Map<String, Object?> environment,
}) async {
  final reportDir = Directory(
    p.join(outputDir.path, 'tasks', safePathSegment(task.id, prefix: 'task')),
  );
  await reportDir.create(recursive: true);
  final reportFile = File(p.join(reportDir.path, 'admission_report.json'));
  final taskBundleDigest = task is FileBackedTask
      ? await taskBundleDigestSha256(task.bundleDirectory)
      : null;
  await reportFile.writeAsString(
    _prettyJson(
      taskQaAdmissionReportJson(
        task: task,
        report: report,
        generatedAt: generatedAt,
        environment: environment,
        taskBundleDigest: taskBundleDigest,
      ),
    ),
  );
  return reportFile;
}

String _relativeOutputPath(Directory root, File file) {
  return p.relative(file.path, from: root.path).replaceAll('\\', '/');
}

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

_TaskQaCliArgs? _parseArgs(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    return null;
  }

  String? outputDir;
  String? workdirRoot;
  var hiddenFlakeRuns = 3;
  Duration? evaluatorTimeout = const Duration(minutes: 2);
  var generatedCodeSandboxRequired = false;
  final taskIds = <String>[];
  final taskBundleRoots = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--out':
        outputDir = _requiredValue(args, ++i, arg);
        break;
      case '--workdir-root':
        workdirRoot = _requiredValue(args, ++i, arg);
        break;
      case '--task':
        taskIds.add(_requiredValue(args, ++i, arg));
        break;
      case '--task-bundle-root':
        taskBundleRoots.add(_requiredValue(args, ++i, arg));
        break;
      case '--hidden-flake-runs':
        hiddenFlakeRuns = _positiveInt(_requiredValue(args, ++i, arg), arg);
        break;
      case '--evaluator-timeout-seconds':
        evaluatorTimeout = Duration(
          seconds: _positiveInt(_requiredValue(args, ++i, arg), arg),
        );
        break;
      case '--require-generated-code-sandbox':
        generatedCodeSandboxRequired = true;
        break;
      default:
        throw TaskQaCliException('unknown argument: $arg');
    }
  }

  if (outputDir == null) {
    throw const TaskQaCliException('--out is required');
  }
  final absoluteOutputDir = p.normalize(p.absolute(outputDir));
  return _TaskQaCliArgs(
    outputDir: absoluteOutputDir,
    workdirRoot: p.normalize(
      p.absolute(workdirRoot ?? p.join(absoluteOutputDir, 'workdirs')),
    ),
    taskIds: List.unmodifiable(taskIds),
    taskBundleRoots: List.unmodifiable(
      taskBundleRoots.map((root) => p.normalize(p.absolute(root))),
    ),
    hiddenFlakeRuns: hiddenFlakeRuns,
    evaluatorTimeout: evaluatorTimeout,
    generatedCodeSandboxRequired: generatedCodeSandboxRequired,
  );
}

String _requiredValue(List<String> args, int index, String option) {
  if (index >= args.length || args[index].startsWith('--')) {
    throw TaskQaCliException('$option requires a value');
  }
  return args[index];
}

int _positiveInt(String value, String option) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw TaskQaCliException('$option must be a positive integer');
  }
  return parsed;
}

Map<String, Object?> _helpJson() {
  return const {
    'status': 'help',
    'usage':
        'dart run --verbosity=error dart_arena:dart_arena_task_qa --out build/task_qa',
    'options': [
      {'name': '--out', 'value': 'path', 'required': true},
      {'name': '--workdir-root', 'value': 'path', 'required': false},
      {'name': '--task', 'value': 'task-id', 'required': false},
      {'name': '--task-bundle-root', 'value': 'path', 'required': false},
      {'name': '--hidden-flake-runs', 'value': 'count', 'required': false},
      {
        'name': '--evaluator-timeout-seconds',
        'value': 'seconds',
        'required': false,
      },
      {'name': '--require-generated-code-sandbox', 'required': false},
      {'name': '--help', 'required': false},
    ],
    'defaults': 'Without --task, validates loaded file-backed tasks.',
  };
}

DateTime _now() => DateTime.now();

RunProvenanceEnvironmentProvider _defaultEnvironmentProvider() {
  return DefaultRunProvenanceEnvironmentProvider();
}

Future<GeneratedCodeSandbox?> _defaultGeneratedCodeSandboxBuilder(
  bool generatedCodeSandboxRequired,
) async {
  if (!generatedCodeSandboxRequired) return null;
  await BubblewrapGeneratedCodeSandbox.ensureAvailable();
  return const BubblewrapGeneratedCodeSandbox();
}

class _TaskQaCliArgs {
  const _TaskQaCliArgs({
    required this.outputDir,
    required this.workdirRoot,
    required this.taskIds,
    required this.taskBundleRoots,
    required this.hiddenFlakeRuns,
    required this.evaluatorTimeout,
    required this.generatedCodeSandboxRequired,
  });

  final String outputDir;
  final String workdirRoot;
  final List<String> taskIds;
  final List<String> taskBundleRoots;
  final int hiddenFlakeRuns;
  final Duration? evaluatorTimeout;
  final bool generatedCodeSandboxRequired;
}
