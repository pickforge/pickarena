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
        'trialSummaries': const <Object?>[],
      },
      taskQaSummary: const <String, Object?>{},
      taskQaReports: const <Map<String, Object?>>[],
      taskBundleDigestEvidence: const [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
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
}
