import 'dart:io';

import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:path/path.dart' as p;

const bubblewrapGeneratedCodeSandboxBackend = 'bubblewrap';

class GeneratedCodeSandboxException implements Exception {
  const GeneratedCodeSandboxException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SandboxedProcessStart {
  const SandboxedProcessStart({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
}

class SandboxResourceLimits {
  const SandboxResourceLimits({this.cpuCores});

  final int? cpuCores;
}

abstract class GeneratedCodeSandbox {
  const GeneratedCodeSandbox();

  String get backend;

  Future<SandboxedProcessStart> wrapProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
    required bool allowInternet,
    SandboxResourceLimits? resourceLimits,
    Iterable<String> extraReadOnlyPaths = const [],
  });
}

class BubblewrapGeneratedCodeSandbox extends GeneratedCodeSandbox {
  const BubblewrapGeneratedCodeSandbox({
    this.bwrapExecutable = 'bwrap',
    this.systemdRunExecutable = 'systemd-run',
  });

  final String bwrapExecutable;
  final String systemdRunExecutable;

  @override
  String get backend => bubblewrapGeneratedCodeSandboxBackend;

  static Future<void> ensureAvailable({
    String executable = 'bwrap',
    String systemdRunExecutable = 'systemd-run',
  }) async {
    if (!Platform.isLinux) {
      throw const GeneratedCodeSandboxException(
        'Bubblewrap generated-code sandbox requires Linux.',
      );
    }
    ProcessResult result;
    try {
      result = await Process.run(
        executable,
        const ['--version'],
        runInShell: false,
        environment: benchmarkSubprocessEnvironment(),
        includeParentEnvironment: false,
      );
    } on Object catch (error) {
      throw GeneratedCodeSandboxException(
        'Bubblewrap generated-code sandbox is required, but "$executable" '
        'could not be started: $error',
      );
    }
    if (result.exitCode != 0) {
      throw GeneratedCodeSandboxException(
        'Bubblewrap generated-code sandbox is required, but "$executable '
        '--version" exited with code ${result.exitCode}: ${result.stderr}',
      );
    }
    await _ensureSystemdRunAvailable(systemdRunExecutable);
  }

  @override
  Future<SandboxedProcessStart> wrapProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
    required bool allowInternet,
    SandboxResourceLimits? resourceLimits,
    Iterable<String> extraReadOnlyPaths = const [],
  }) async {
    if (!Platform.isLinux) {
      throw const GeneratedCodeSandboxException(
        'Bubblewrap generated-code sandbox requires Linux.',
      );
    }

    final workDir = p.normalize(p.absolute(workingDirectory));
    final sandboxEnvironment = Map<String, String>.from(environment);
    _suppressToolTelemetry(sandboxEnvironment);
    final executablePath = await _resolveExecutablePath(
      executable,
      sandboxEnvironment,
    );
    final executableRoot = await _toolRootFor(executablePath);
    final flutterRoot = await _flutterRootFor(executablePath);
    final dartSdkBin = await _dartSdkBinFor(
      executablePath: executablePath,
      executableRoot: executableRoot,
      flutterRoot: flutterRoot,
    );
    if (dartSdkBin != null) {
      sandboxEnvironment['PATH'] = _prependPath(
        dartSdkBin,
        sandboxEnvironment['PATH'],
      );
    }

    final sandboxExecutable = dartSdkBin == null
        ? executablePath ?? executable
        : _dartExecutableFor(executable, executablePath, dartSdkBin);
    final bwrapArgs = <String>[
      '--die-with-parent',
      '--tmpfs',
      '/',
      ..._readOnlySystemBinds(),
      '--tmpfs',
      '/tmp',
      '--dir',
      '/var',
      '--tmpfs',
      '/var/tmp',
      '--dev',
      '/dev',
      '--proc',
      '/proc',
      '--unshare-pid',
      '--unshare-ipc',
      '--new-session',
      if (!allowInternet) '--unshare-net',
      if (executableRoot != null) ...[
        '--ro-bind',
        executableRoot,
        executableRoot,
      ],
      if (flutterRoot != null)
        ...await _flutterWritableCacheFileBinds(
          flutterRoot: flutterRoot,
          workDir: workDir,
        ),
      ..._extraReadOnlyBinds(extraReadOnlyPaths),
      ...await _pubCacheBinds(
        environment: sandboxEnvironment,
        workDir: workDir,
        allowInternet: allowInternet,
      ),
      '--bind',
      workDir,
      workDir,
      '--chdir',
      workDir,
      sandboxExecutable,
      ...arguments,
    ];

    final processStart = SandboxedProcessStart(
      executable: bwrapExecutable,
      arguments: bwrapArgs,
      workingDirectory: workDir,
      environment: sandboxEnvironment,
    );
    return _wrapWithSystemdRun(processStart, resourceLimits);
  }

  List<String> _extraReadOnlyBinds(Iterable<String> paths) {
    final args = <String>[];
    final seen = <String>{};
    for (final path in paths) {
      final normalized = p.normalize(p.absolute(path));
      if (!seen.add(normalized)) continue;
      if (!_entityExists(normalized)) {
        throw GeneratedCodeSandboxException(
          'Generated-code sandbox read-only bind path does not exist: '
          '$normalized',
        );
      }
      args.addAll(['--ro-bind', normalized, normalized]);
    }
    return args;
  }

  static Future<void> _ensureSystemdRunAvailable(String executable) async {
    ProcessResult result;
    try {
      result = await Process.run(
        executable,
        const [
          '--user',
          '--scope',
          '--quiet',
          '--expand-environment=no',
          '-p',
          'CPUQuota=100%',
          '/usr/bin/env',
          'true',
        ],
        runInShell: false,
        environment: benchmarkSubprocessEnvironment(),
        includeParentEnvironment: false,
      );
    } on Object catch (error) {
      throw GeneratedCodeSandboxException(
        'Bubblewrap generated-code sandbox requires a user systemd cgroup '
        'scope for CPU enforcement, but "$executable" could not be started: '
        '$error',
      );
    }
    if (result.exitCode != 0) {
      throw GeneratedCodeSandboxException(
        'Bubblewrap generated-code sandbox requires a user systemd cgroup '
        'scope for CPU enforcement, but "$executable --user --scope" exited '
        'with code ${result.exitCode}: ${result.stderr}',
      );
    }
  }

  SandboxedProcessStart _wrapWithSystemdRun(
    SandboxedProcessStart processStart,
    SandboxResourceLimits? resourceLimits,
  ) {
    final cpuCores = resourceLimits?.cpuCores;
    if (cpuCores == null) return processStart;
    if (cpuCores <= 0) {
      throw GeneratedCodeSandboxException(
        'Generated-code CPU limit must be positive, got $cpuCores.',
      );
    }
    return SandboxedProcessStart(
      executable: systemdRunExecutable,
      arguments: [
        '--user',
        '--scope',
        '--quiet',
        '--expand-environment=no',
        '-p',
        'CPUQuota=${cpuCores * 100}%',
        processStart.executable,
        ...processStart.arguments,
      ],
      workingDirectory: processStart.workingDirectory,
      environment: _systemdRunEnvironment(processStart.environment),
    );
  }

  Map<String, String> _systemdRunEnvironment(
    Map<String, String> sandboxEnvironment,
  ) {
    final environment = Map<String, String>.from(sandboxEnvironment);
    for (final key in const ['XDG_RUNTIME_DIR', 'DBUS_SESSION_BUS_ADDRESS']) {
      final value = Platform.environment[key];
      if ((environment[key] == null || environment[key]!.isEmpty) &&
          value != null &&
          value.isNotEmpty) {
        environment[key] = value;
      }
    }
    return environment;
  }

  void _suppressToolTelemetry(Map<String, String> environment) {
    environment
      ..['DART_SUPPRESS_ANALYTICS'] = 'true'
      ..['FLUTTER_SUPPRESS_ANALYTICS'] = 'true';
  }

  List<String> _readOnlySystemBinds() {
    final args = <String>[];
    for (final path in const ['/usr', '/bin', '/lib', '/lib64', '/etc']) {
      if (_entityExists(path)) args.addAll(['--ro-bind', path, path]);
    }
    return args;
  }

  Future<List<String>> _pubCacheBinds({
    required Map<String, String> environment,
    required String workDir,
    required bool allowInternet,
  }) async {
    final pubCache = environment['PUB_CACHE'];
    if (pubCache == null || pubCache.trim().isEmpty) return const [];
    final normalizedPubCache = p.normalize(p.absolute(pubCache));
    if (allowInternet) {
      final localPubCache = p.join(workDir, '.dart_arena', 'pub-cache');
      await Directory(localPubCache).create(recursive: true);
      environment['PUB_CACHE'] = localPubCache;
      return const [];
    }
    if (!_entityExists(normalizedPubCache)) return const [];
    final activeRoots = p.join(
      workDir,
      '.dart_arena',
      'pub-cache-active-roots',
    );
    await Directory(activeRoots).create(recursive: true);
    return [
      '--ro-bind',
      normalizedPubCache,
      normalizedPubCache,
      '--bind',
      activeRoots,
      p.join(normalizedPubCache, 'active_roots'),
    ];
  }

  Future<List<String>> _flutterWritableCacheFileBinds({
    required String flutterRoot,
    required String workDir,
  }) async {
    final cacheDir = Directory(p.join(flutterRoot, 'bin', 'cache'));
    if (!await cacheDir.exists()) return const [];
    final overlayDir = Directory(
      p.join(workDir, '.dart_arena', 'flutter-cache-files'),
    );
    await overlayDir.create(recursive: true);
    final binds = <String>[];
    final overlayNames = {'lockfile'};
    await for (final entity in cacheDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final basename = p.basename(entity.path);
      if (basename.endsWith('.stamp') || basename == 'engine.realm') {
        overlayNames.add(basename);
      }
    }
    for (final basename in overlayNames) {
      final source = File(p.join(cacheDir.path, basename));
      final overlay = File(p.join(overlayDir.path, basename));
      if (await source.exists()) {
        await overlay.writeAsBytes(await source.readAsBytes());
      } else {
        await overlay.writeAsBytes(const []);
      }
      binds.addAll(['--bind', overlay.path, source.path]);
    }
    return binds;
  }

  String _dartExecutableFor(
    String requestedExecutable,
    String? executablePath,
    String dartSdkBin,
  ) {
    final requestedName = p.basename(requestedExecutable);
    final resolvedName = executablePath == null
        ? null
        : p.basename(executablePath);
    if (requestedName == 'dart' || resolvedName == 'dart') {
      return p.join(dartSdkBin, 'dart');
    }
    return executablePath ?? requestedExecutable;
  }

  Future<String?> _resolveExecutablePath(
    String executable,
    Map<String, String> environment,
  ) async {
    if (p.isAbsolute(executable)) {
      return _entityExists(executable)
          ? await _realPath(executable)
          : executable;
    }
    final path = environment['PATH'] ?? Platform.environment['PATH'];
    if (path == null || path.isEmpty) return null;
    for (final dir in path.split(':')) {
      if (dir.isEmpty) continue;
      final candidate = p.join(dir, executable);
      if (_entityExists(candidate)) return _realPath(candidate);
    }
    return null;
  }

  Future<String?> _toolRootFor(String? executablePath) async {
    if (executablePath == null) return null;
    final normalized = p.normalize(executablePath);
    if (_isCoveredBySystemBind(normalized)) return null;
    final flutterRoot = await _flutterRootFor(normalized);
    if (flutterRoot != null) return flutterRoot;
    final dartSdkRoot = await _dartSdkRootFor(normalized);
    if (dartSdkRoot != null) return dartSdkRoot;
    return FileSystemEntity.isDirectorySync(normalized)
        ? normalized
        : p.dirname(normalized);
  }

  Future<String?> _flutterRootFor(String? executablePath) async {
    if (executablePath == null) return null;
    var current = FileSystemEntity.isDirectorySync(executablePath)
        ? Directory(executablePath)
        : File(executablePath).parent;
    while (true) {
      if (await File(p.join(current.path, 'bin', 'flutter')).exists() &&
          await Directory(p.join(current.path, 'bin', 'cache')).exists()) {
        return p.normalize(current.path);
      }
      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
  }

  Future<String?> _dartSdkRootFor(String? executablePath) async {
    if (executablePath == null) return null;
    var current = FileSystemEntity.isDirectorySync(executablePath)
        ? Directory(executablePath)
        : File(executablePath).parent;
    while (true) {
      if (await File(p.join(current.path, 'bin', 'dart')).exists() &&
          await Directory(p.join(current.path, 'bin', 'snapshots')).exists()) {
        return p.normalize(current.path);
      }
      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
  }

  Future<String?> _dartSdkBinFor({
    required String? executablePath,
    required String? executableRoot,
    required String? flutterRoot,
  }) async {
    final candidates = <String>[
      if (flutterRoot != null)
        p.join(flutterRoot, 'bin', 'cache', 'dart-sdk', 'bin'),
      if (executableRoot != null && p.basename(executableRoot) != 'bin')
        p.join(executableRoot, 'bin'),
      if (executablePath != null) p.dirname(executablePath),
    ];
    for (final candidate in candidates) {
      if (await File(p.join(candidate, 'dart')).exists()) {
        return p.normalize(candidate);
      }
    }
    return null;
  }

  bool _isCoveredBySystemBind(String path) {
    for (final root in const ['/usr', '/bin', '/lib', '/lib64']) {
      if (path == root || p.isWithin(root, path)) return true;
    }
    return false;
  }

  String _prependPath(String path, String? existing) {
    if (existing == null || existing.isEmpty) return path;
    final parts = existing.split(':');
    if (parts.contains(path)) return existing;
    return '$path:$existing';
  }

  Future<String> _realPath(String path) async {
    try {
      return await File(path).resolveSymbolicLinks();
    } on Object {
      return path;
    }
  }

  bool _entityExists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: true) !=
      FileSystemEntityType.notFound;
}
