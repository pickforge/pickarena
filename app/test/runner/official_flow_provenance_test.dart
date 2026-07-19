import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_integrity.dart';
import 'package:dart_arena/runner/agentic_run_orchestrator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/file_backed_bundle_fixture.dart';

/// Official-flow provenance integration test: an agent edits a real
/// file-backed task workspace, the captured patch is replayed into a clean
/// grading workspace, and the end-to-end provenance record reflects it.
void main() {
  test(
    'patch -> clean grading workspace -> provenance record end to end',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_official_flow_provenance_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final bundleRoot = Directory(p.join(root.path, 'bundles'));
      await writeAnswerFileBackedBundle(bundleRoot);
      final task = (await loadFileBackedTasks(bundleRoot)).single;
      await task.ensureLoaded();

      final workdirRoot = Directory(p.join(root.path, 'workdirs'))
        ..createSync();
      final harness = _PatchingHarness();
      final result =
          await AgenticRunOrchestrator(
            workdirManager: WorkdirManager(root: workdirRoot),
          ).run(
            runId: 'official-flow-run',
            task: task,
            harness: harness,
            providerId: 'fake',
            modelId: 'fake-model',
            trialIndex: 0,
            evaluatorConfig: const EvaluatorConfig(),
          );

      // The agent never saw the hidden verifier in its workspace.
      expect(
        File(
          p.join(
            harness.workspace!.path,
            'test',
            '_hidden',
            'answer_hidden_test.dart',
          ),
        ).existsSync(),
        isFalse,
      );

      // The captured patch reflects exactly the agent's edit.
      expect(result.patchText, contains('-int answer() => 41;'));
      expect(result.patchText, contains('+int answer() => 42;'));

      // Grading happened via clean replay in the sibling grading workspace.
      expect(result.provenance['gradingMode'], 'clean_replay');
      expect(result.provenance['patchApplied'], isTrue);
      expect(
        result.provenance['patchSha256'],
        sha256.convert(utf8.encode(result.patchText!)).toString(),
      );
      final gradingWorkspace = Directory(
        p.join(p.dirname(harness.workspace!.path), 'trial_0_grading'),
      );
      expect(gradingWorkspace.existsSync(), isTrue);
      expect(
        File(
          p.join(gradingWorkspace.path, 'lib', 'answer.dart'),
        ).readAsStringSync(),
        'int answer() => 42;\n',
      );

      // Hidden-fixture isolation evidence is recorded with no leaks.
      final isolation =
          result.provenance['hiddenFixtureIsolation'] as Map<String, Object?>;
      expect(isolation['asserted'], isTrue);
      expect(isolation['leakedPaths'], isEmpty);

      // The provenance record pins the hidden verifier digests of the bundle.
      expect(
        result.provenance['hiddenVerifierDigests'],
        hiddenVerifierDigests(task),
      );

      // The hidden verifier passed against the replayed patch.
      final hidden = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'answer_hidden',
      );
      expect(hidden.passed, isTrue, reason: hidden.rationale);
      expect(result.primaryPass, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: Platform.isWindows,
  );
}

class _PatchingHarness implements AgentHarness {
  Directory? workspace;

  @override
  String get id => 'official-flow-fake';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
  }) async {
    this.workspace = workspace;
    await File(
      p.join(workspace.path, 'lib', 'answer.dart'),
    ).writeAsString('int answer() => 42;\n');
    return const AgentRunResult(
      status: AgentRunStatus.success,
      stdoutPreview: 'patched answer.dart',
      stderrPreview: '',
      exitCode: 0,
      latency: Duration(milliseconds: 10),
    );
  }
}
