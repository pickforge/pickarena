import 'package:dart_arena/core/task_bundle_digest.dart';
import 'package:dart_arena/export/release_report.dart';
import 'package:test/test.dart';

void main() {
  test('blocks stale replay provenance and corpus manifest entries', () {
    const taskBundleDigest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final manifestDigest = corpusManifestDigestSha256(const [
      CorpusManifestEntry(
        taskId: 'task.a',
        taskVersion: 1,
        taskBundleDigest: taskBundleDigest,
      ),
    ]);
    final report = buildReleaseReport(
      leaderboard: {
        'benchmark': {
          'dataPolicy': 'aggregate-compatible',
          'version': 'v1',
          'taskSetId': 'set',
          'evaluatorSchemaVersion': 2,
          'preset': 'official',
          'selectedTasks': [
            {
              'taskId': 'task.a',
              'taskVersion': 1,
              'taskBundleDigest': taskBundleDigest,
            },
          ],
          'corpusManifestDigestSha256': manifestDigest,
        },
        'source': {
          'runIds': ['run-1'],
          'taskRunCount': 1,
          'runProvenance': const <String, Object?>{},
        },
        'models': const <Object?>[],
        'tasks': [
          {
            'taskId': 'task.a',
            'taskVersion': 1,
            'taskBundleDigest':
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        ],
        'taskModelCells': const <Object?>[],
        'trialSummaries': const [
          {
            'runId': 'run-1',
            'taskId': 'task.a',
            'taskVersion': 1,
            'benchmarkTrack': 'agentic',
            'providerId': 'p',
            'modelId': 'm',
            'trialIndex': 0,
          },
        ],
      },
      taskQaSummary: const <String, Object?>{},
      taskQaReports: const <Map<String, Object?>>[],
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'hiddenVerifierDigests': {
            'hidden_test':
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          },
        },
      ],
      runProvenanceById: {
        'run-1': {
          'combos': const [
            {
              'taskId': 'task.a',
              'providerId': 'p',
              'modelId': 'm',
              'trialIndex': 0,
            },
          ],
          'resultProvenance': const [
            {
              'taskId': 'task.a',
              'taskVersion': 1,
              'benchmarkTrack': 'agentic',
              'providerId': 'p',
              'modelId': 'm',
              'trialIndex': 0,
              'gradingMode': 'agent_workspace',
              'hiddenFixtureIsolation': {
                'asserted': true,
                'leakedPaths': ['test/_hidden/answer_hidden_test.dart'],
              },
              'hiddenVerifierDigests': {
                'hidden_test':
                    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
              },
            },
          ],
        },
      },
      options: const ReleaseReportOptions(releaseId: 'test'),
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Result was graded in the agent workspace, not a clean replay baseline.',
      ),
    );
    expect(
      blockers,
      contains(
        'Hidden verifier fixtures were readable from the agent workspace.',
      ),
    );
    expect(
      blockers,
      contains(
        'Hidden verifier digests drifted from the corpus since the run.',
      ),
    );
    expect(
      blockers,
      contains(
        'Leaderboard frozen corpus manifest entries do not match leaderboard tasks.',
      ),
    );
    final provenance = report['provenance']! as Map<String, Object?>;
    expect(provenance['cleanReplayResultCount'], 0);
    expect(provenance['hiddenFixtureIsolationLeakResultCount'], 1);
  });

  test('scopes frozen manifest rows and blocks exported live drift', () {
    const agenticDigest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const codegenDigest =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final manifestEntries = const [
      CorpusManifestEntry(
        taskId: 'task.agentic',
        taskVersion: 1,
        taskBundleDigest: agenticDigest,
      ),
      CorpusManifestEntry(
        taskId: 'task.codegen',
        taskVersion: 1,
        taskBundleDigest: codegenDigest,
      ),
    ];
    final report = buildReleaseReport(
      leaderboard: {
        'benchmark': {
          'dataPolicy': 'aggregate-compatible',
          'version': 'v1',
          'taskSetId': 'set',
          'evaluatorSchemaVersion': 2,
          'track': 'agentic',
          'preset': 'mixed',
          'selectedTasks': [
            for (final entry in manifestEntries) entry.toJson(),
          ],
          'corpusManifestDigestSha256': corpusManifestDigestSha256(
            manifestEntries,
          ),
        },
        'source': const {
          'runIds': <String>[],
          'taskRunCount': 0,
          'runProvenance': <String, Object?>{},
        },
        'models': const <Object?>[],
        'tasks': const [
          {
            'taskId': 'task.agentic',
            'taskVersion': 1,
            'benchmarkTrack': 'agentic',
            'taskBundleDigest': agenticDigest,
          },
        ],
        'taskModelCells': const <Object?>[],
        'trialSummaries': const <Object?>[],
      },
      taskQaSummary: const <String, Object?>{},
      taskQaReports: const <Map<String, Object?>>[],
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.agentic',
          'taskVersion': 1,
          'track': 'agentic',
          'taskBundleDigest':
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        },
      ],
      options: const ReleaseReportOptions(releaseId: 'test'),
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      isNot(
        contains(
          'Leaderboard frozen corpus manifest entries do not match leaderboard tasks.',
        ),
      ),
    );
    expect(
      blockers,
      contains(
        'Full task bundle digest drifted from the frozen corpus manifest '
        'since the run.',
      ),
    );
  });

  test('blocks when live hidden verifier evidence is absent', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const <Map<String, Object?>>[],
      hiddenVerifierDigests: const {'hidden_test': 'aa'},
    );
    expect(
      blockers,
      contains(
        'Could not recompute hidden verifier digests from the live task '
        'bundle for a graded result.',
      ),
    );
    expect(
      blockers,
      isNot(
        contains(
          'Hidden verifier digests drifted from the corpus '
          'since the run.',
        ),
      ),
    );
  });

  test('does not block a task that legitimately has no hidden verifiers', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'hiddenVerifierDigests': <String, Object?>{},
        },
      ],
      hiddenVerifierDigests: const <String, Object?>{},
    );
    expect(
      blockers,
      isNot(
        contains(
          'Hidden verifier digests drifted from the corpus '
          'since the run.',
        ),
      ),
    );
    expect(
      blockers,
      isNot(
        contains(
          'Could not recompute hidden verifier digests from the '
          'live task bundle for a graded result.',
        ),
      ),
    );
  });

  test('blocks when digest evidence lacks a hiddenVerifierDigests field', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {'taskId': 'task.a', 'taskVersion': 1, 'track': 'agentic'},
      ],
      hiddenVerifierDigests: const <String, Object?>{},
    );
    expect(
      blockers,
      contains(
        'Could not recompute hidden verifier digests from the live task '
        'bundle for a graded result.',
      ),
    );
  });

  test('blocks when clean-replay workspace paths are not distinct', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'hiddenVerifierDigests': <String, Object?>{},
        },
      ],
      hiddenVerifierDigests: const <String, Object?>{},
      gradingWorkspacePath: '/work/agent',
    );
    expect(
      blockers,
      contains(
        'Result does not independently prove that grading used a workspace '
        'separate from the agent workspace.',
      ),
    );
  });

  test('blocks full task bundle digest drift', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'taskBundleDigest':
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          'hiddenVerifierDigests': <String, Object?>{},
        },
      ],
      hiddenVerifierDigests: const <String, Object?>{},
    );
    expect(
      blockers,
      contains(
        'Full task bundle digest drifted from the corpus since the run.',
      ),
    );
  });

  test('blocks result provenance whose track differs from its export', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'hiddenVerifierDigests': <String, Object?>{},
        },
      ],
      hiddenVerifierDigests: const <String, Object?>{},
      benchmarkTrack: 'codegen',
    );
    expect(
      blockers,
      contains(
        'Run run-1 does not contain each exported planned result combo '
        'exactly once in stored provenance.',
      ),
    );
  });

  test('blocks duplicate provenance that masks an omitted exported combo', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'hiddenVerifierDigests': <String, Object?>{},
        },
      ],
      hiddenVerifierDigests: const <String, Object?>{},
      resultCopies: 2,
    );
    expect(
      blockers,
      contains(
        'Run run-1 does not contain each exported planned result combo '
        'exactly once in stored provenance.',
      ),
    );
  });

  test('ignores fresh-execution provenance outside exported trials', () {
    final blockers = _provenanceBlockers(
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'hiddenVerifierDigests': <String, Object?>{},
        },
      ],
      hiddenVerifierDigests: const <String, Object?>{},
      includeUnexportedCodegenResult: true,
    );
    expect(
      blockers,
      isNot(
        contains(
          'Result was graded in the agent workspace, not a clean replay baseline.',
        ),
      ),
    );
  });

  test(
    'blocks an agentic result whose provenance omits the benchmark track',
    () {
      final blockers = _provenanceBlockers(
        taskBundleDigestEvidence: const [
          {
            'taskId': 'task.a',
            'taskVersion': 1,
            'track': 'agentic',
            'hiddenVerifierDigests': {'hidden_test': 'aa'},
          },
        ],
        hiddenVerifierDigests: const {'hidden_test': 'aa'},
        benchmarkTrack: null,
      );
      expect(
        blockers,
        contains(
          'Run run-1 does not contain each exported planned result combo '
          'exactly once in stored provenance.',
        ),
      );
    },
  );
}

Map<String, Object?> _workspaceIsolationEvidence() => {
  for (final stage in const ['preAgent', 'postAgent'])
    stage: const {
      'workdirUnderRunsRoot': true,
      'rootConfined': true,
      'relativePathsOnly': true,
      'restrictedPathsAbsent': true,
      'restrictedPathCount': 0,
      'symlinkCount': 0,
      'unreadableFileCount': 0,
      'symlinksFollowed': false,
    },
};

String _provenanceBlockers({
  required List<Map<String, Object?>> taskBundleDigestEvidence,
  required Map<String, Object?> hiddenVerifierDigests,
  String? benchmarkTrack = 'agentic',
  String gradingWorkspacePath = '/work/grading',
  int resultCopies = 1,
  bool includeUnexportedCodegenResult = false,
}) {
  final report = buildReleaseReport(
    leaderboard: {
      'benchmark': const {
        'dataPolicy': 'aggregate-compatible',
        'version': 'v1',
        'taskSetId': 'set',
        'evaluatorSchemaVersion': 2,
      },
      'source': {
        'runIds': const ['run-1'],
        'taskRunCount': 1,
        'runProvenance': const <String, Object?>{},
      },
      'models': const <Object?>[],
      'tasks': const <Object?>[],
      'trialSummaries': [
        const {
          'runId': 'run-1',
          'taskId': 'task.a',
          'taskVersion': 1,
          'benchmarkTrack': 'agentic',
          'providerId': 'p',
          'modelId': 'm',
          'trialIndex': 0,
        },
        if (resultCopies > 1)
          const {
            'runId': 'run-1',
            'taskId': 'task.b',
            'taskVersion': 1,
            'benchmarkTrack': 'agentic',
            'providerId': 'p',
            'modelId': 'm',
            'trialIndex': 0,
          },
      ],
    },
    taskQaSummary: const <String, Object?>{},
    taskQaReports: const <Map<String, Object?>>[],
    taskBundleDigestEvidence: [
      for (final evidence in taskBundleDigestEvidence)
        {
          ...evidence,
          if (!evidence.containsKey('taskBundleDigest'))
            'taskBundleDigest':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        },
    ],
    runProvenanceById: {
      'run-1': {
        'combos': [
          const {
            'taskId': 'task.a',
            'providerId': 'p',
            'modelId': 'm',
            'trialIndex': 0,
          },
          if (resultCopies > 1)
            const {
              'taskId': 'task.b',
              'providerId': 'p',
              'modelId': 'm',
              'trialIndex': 0,
            },
          if (includeUnexportedCodegenResult)
            const {
              'taskId': 'task.codegen',
              'providerId': 'p',
              'modelId': 'm',
              'trialIndex': 0,
            },
        ],
        'resultProvenance': [
          for (var copy = 0; copy < resultCopies; copy++)
            {
              'taskId': 'task.a',
              'taskVersion': 1,
              if (benchmarkTrack != null) 'benchmarkTrack': benchmarkTrack,
              'providerId': 'p',
              'modelId': 'm',
              'trialIndex': 0,
              'gradingMode': 'clean_replay',
              'taskBundleDigest':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'workspacePaths': {
                'agent': '/work/agent',
                'grading': gradingWorkspacePath,
              },
              'agentWorkspaceIsolation': _workspaceIsolationEvidence(),
              'hiddenFixtureIsolation': const {
                'asserted': true,
                'leakedPaths': <String>[],
                'preAgentManifestSha256':
                    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                'postAgentManifestSha256':
                    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
              },
              'hiddenVerifierDigests': hiddenVerifierDigests,
            },
          if (includeUnexportedCodegenResult)
            const {
              'taskId': 'task.codegen',
              'taskVersion': 1,
              'benchmarkTrack': 'codegen',
              'providerId': 'p',
              'modelId': 'm',
              'trialIndex': 0,
              'gradingMode': 'agent_workspace',
            },
        ],
      },
    },
    options: const ReleaseReportOptions(releaseId: 'test'),
  );
  return (report['blockers']! as List<Object?>).join('\n');
}
