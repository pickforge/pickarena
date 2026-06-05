import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:path/path.dart' as p;

class HiddenTestEvaluator implements Evaluator {
  HiddenTestEvaluator(
    this.verifier, {
    this.timeout,
    this.maxOutputChars = TestEvaluator.defaultMaxOutputChars,
    this.maxProcesses,
    this.maxMemoryMb,
  });

  final VerifierFixture verifier;
  final Duration? timeout;
  final int maxOutputChars;
  final int? maxProcesses;
  final int? maxMemoryMb;

  @override
  String get id => verifier.id;

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    try {
      resolveWorkspaceFile(ctx.workDir, verifier.testPath);
      for (final path in verifier.files.keys) {
        resolveWorkspaceFile(ctx.workDir, path);
      }
    } on ArgumentError catch (e) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'hidden verifier path rejected',
        details: {
          'error': 'invalid workspace-relative path',
          'path': e.invalidValue?.toString(),
        },
      );
    }

    Directory? stagingRoot;
    final injected = <String, File>{};
    try {
      stagingRoot = await Directory.systemTemp.createTemp(
        'dart_arena_hidden_verifier_',
      );
      for (final entry in verifier.files.entries) {
        final file = File(p.join(stagingRoot.path, entry.key));
        injected[entry.key] = file;
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value);
      }
      final stagedTestPath = p.join(stagingRoot.path, verifier.testPath);

      final result = await TestEvaluator(
        testPath: stagedTestPath,
        timeout: timeout,
        maxOutputChars: maxOutputChars,
        maxProcesses: maxProcesses,
        maxMemoryMb: maxMemoryMb,
        readOnlyPaths: [stagingRoot.path],
      ).evaluate(ctx);
      final tamperedFiles = await _tamperedInjectedFiles(injected);
      if (tamperedFiles.isNotEmpty) {
        return EvaluationResult(
          evaluatorId: id,
          passed: false,
          score: 0.0,
          rationale: 'hidden verifier tampered',
          details: {
            'code': 'infrastructure_error',
            'reason': 'hidden_verifier_tampered',
            'test_path': verifier.testPath,
            'tampered_files': tamperedFiles,
            'injected_files': injected.keys.toList(growable: false),
          },
        );
      }
      final total = result.details['total'] as int? ?? 0;
      final passed = result.details['passed'] as int? ?? 0;
      final failed = result.details['failed'] as int? ?? 0;
      final errored = result.details['errored'] as int? ?? 0;
      final timedOut = result.details['timed_out'] == true;
      final outputLimitExceeded =
          result.details['output_limit_exceeded'] == true;
      final processLimitExceeded =
          result.details['process_limit_exceeded'] == true;
      final memoryLimitExceeded =
          result.details['memory_limit_exceeded'] == true;
      return EvaluationResult(
        evaluatorId: id,
        passed:
            !timedOut &&
            !outputLimitExceeded &&
            !processLimitExceeded &&
            !memoryLimitExceeded &&
            result.passed,
        score:
            (outputLimitExceeded || processLimitExceeded || memoryLimitExceeded)
            ? 0.0
            : result.score,
        rationale: timedOut
            ? 'hidden verifier timed out'
            : processLimitExceeded
            ? 'hidden verifier process limit exceeded'
            : memoryLimitExceeded
            ? 'hidden verifier memory limit exceeded'
            : outputLimitExceeded
            ? 'hidden verifier output limit exceeded'
            : total == 0
            ? 'no hidden tests found'
            : '$passed/$total hidden tests passed',
        details: {
          'total': total,
          'passed': passed,
          'failed': failed,
          'errored': errored,
          'failures': _sanitizedFailures(failed + errored),
          'exit_code': result.details['exit_code'],
          if (timedOut) 'timed_out': true,
          if (result.details['timeout_ms'] != null)
            'timeout_ms': result.details['timeout_ms'],
          if (outputLimitExceeded) 'output_limit_exceeded': true,
          if (outputLimitExceeded && result.details['max_output_chars'] != null)
            'max_output_chars': result.details['max_output_chars'],
          if (processLimitExceeded) 'process_limit_exceeded': true,
          if (processLimitExceeded && result.details['max_processes'] != null)
            'max_processes': result.details['max_processes'],
          if (result.details['observed_processes'] != null)
            'observed_processes': result.details['observed_processes'],
          if (memoryLimitExceeded) 'memory_limit_exceeded': true,
          if (memoryLimitExceeded && result.details['max_memory_mb'] != null)
            'max_memory_mb': result.details['max_memory_mb'],
          if (result.details['observed_memory_mb'] != null)
            'observed_memory_mb': result.details['observed_memory_mb'],
          'tool': result.details['tool'],
          'test_path': verifier.testPath,
          'injected_files': injected.keys.toList(growable: false),
        },
      );
    } on Object catch (e) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'hidden verifier failed to run',
        details: {
          'error': e.toString(),
          'test_path': verifier.testPath,
          'injected_files': injected.keys.toList(growable: false),
        },
      );
    } finally {
      final root = stagingRoot;
      if (root != null && await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  }

  List<Map<String, Object>> _sanitizedFailures(int count) {
    return List<Map<String, Object>>.generate(
      count,
      (i) => {'index': i + 1, 'message': 'hidden verifier failure'},
    );
  }

  Future<List<String>> _tamperedInjectedFiles(
    Map<String, File> injected,
  ) async {
    final tampered = <String>[];
    for (final entry in verifier.files.entries) {
      final file = injected[entry.key];
      if (file == null || !await file.exists()) {
        tampered.add(entry.key);
        continue;
      }
      final contents = await _tryRead(file);
      if (contents != entry.value) {
        tampered.add(entry.key);
      }
    }
    return tampered;
  }

  Future<String?> _tryRead(File file) async {
    try {
      return await file.readAsString();
    } on Object {
      return null;
    }
  }
}
