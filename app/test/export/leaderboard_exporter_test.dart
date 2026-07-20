import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_arena/export/leaderboard_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'shared leaderboard compatibility corpus matches its manifest',
    () async {
      final manifest = await _loadLeaderboardFixtureManifest();
      for (final entry in _fixtureEntries(manifest.decoded)) {
        final fixtureBytes = await File.fromUri(
          manifest.uri.resolve(entry['file']! as String),
        ).readAsBytes();
        expect(
          sha256.convert(fixtureBytes).toString(),
          entry['sha256'],
          reason: entry['id']! as String,
        );

        final normalized = _normalizeLeaderboardFixture(
          utf8.decode(fixtureBytes),
        );
        expect(
          normalized == null ? 'reject' : 'accept',
          entry['outcome'],
          reason: entry['id']! as String,
        );
        expect(
          normalized,
          entry['normalizedProjection'],
          reason: entry['id']! as String,
        );
      }
    },
  );

  test('fixed current export matches the current-v2 projection', () async {
    await _seedRun(
      db,
      id: 'compat-run',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _presetProvenanceJson(includeTaskB: false),
    );
    await _seedTaskRun(
      db,
      id: 'compat-trial',
      runId: 'compat-run',
      taskId: 'task.a',
      completedAt: DateTime.utc(2026, 5, 1, 12),
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );
    final manifest = await _loadLeaderboardFixtureManifest();
    final current = _fixtureEntries(
      manifest.decoded,
    ).singleWhere((entry) => entry['id'] == 'current-v2');
    final fixtureBytes = await File.fromUri(
      manifest.uri.resolve(current['file']! as String),
    ).readAsBytes();

    expect(jsonDecode(utf8.decode(fixtureBytes)), export);
    expect(
      _normalizeLeaderboardFixture(jsonEncode(export)),
      current['normalizedProjection'],
    );
  });

  test('aggregate-compatible aggregates compatible completed runs', () async {
    await _seedRun(
      db,
      id: 'compatible-old',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _presetProvenanceJson(),
    );
    await _seedTaskRun(
      db,
      id: 'old-a',
      runId: 'compatible-old',
      taskId: 'task.a',
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'old-b',
      runId: 'compatible-old',
      taskId: 'task.b',
      primaryPass: false,
      failureTag: 'test_failed',
    );
    await _seedRun(
      db,
      id: 'compatible-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _presetProvenanceJson(),
    );
    await _seedTaskRun(
      db,
      id: 'latest-a',
      runId: 'compatible-latest',
      taskId: 'task.a',
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'latest-b',
      runId: 'compatible-latest',
      taskId: 'task.b',
      primaryPass: null,
      failureTag: 'unknown',
    );
    await _seedRun(
      db,
      id: 'incompatible-version',
      completedAt: DateTime.utc(2026, 4, 30),
    );
    await _seedTaskRun(
      db,
      id: 'incompatible-a',
      runId: 'incompatible-version',
      taskId: 'task.a',
      taskVersion: 2,
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'incompatible-b',
      runId: 'incompatible-version',
      taskId: 'task.b',
      primaryPass: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    expect(export['generatedAt'], '2026-05-31T00:00:00.000Z');
    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'compatible-latest');
    expect(source['runIds'], ['compatible-latest', 'compatible-old']);
    expect(source['taskCount'], 2);
    expect(source['taskRunCount'], 4);
    expect(source['modelCount'], 1);
    expect(source['warnings'], isEmpty);

    final benchmark = export['benchmark']! as Map<String, Object?>;
    expect(benchmark['dataPolicy'], 'aggregate-compatible');
    expect(benchmark['track'], 'agentic');
    expect(benchmark['version'], '2026-05-31-master-spec');
    expect(benchmark['taskSetId'], startsWith('taskset-'));
    expect(benchmark['evaluatorSchemaVersion'], 2);
    expect(benchmark['preset'], 'mvp');
    expect(benchmark['corpusManifestDigestSha256'], hasLength(64));
    expect(benchmark['selectedTasks'], hasLength(2));

    final pricingRegistry = export['pricingRegistry']! as Map<String, Object?>;
    expect(pricingRegistry['version'], '2026-05-31');
    expect(pricingRegistry['currency'], 'USD');
    expect(pricingRegistry['modelCount'], greaterThan(0));
  });

  test(
    'aggregate-compatible separates harness kinds from provenance',
    () async {
      await _seedRun(
        db,
        id: 'minimal-old',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: _harnessProvenanceJson('minimal'),
      );
      await _seedTaskRun(
        db,
        id: 'minimal-old-a',
        runId: 'minimal-old',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'command-same-kind',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _harnessProvenanceJson(
          'command-template',
          agent: 'codex',
          version: '1.0.0',
        ),
      );
      await _seedTaskRun(
        db,
        id: 'command-same-kind-a',
        runId: 'command-same-kind',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'command-latest',
        completedAt: DateTime.utc(2026, 5, 3),
        provenanceJson: _harnessProvenanceJson(
          'command-template',
          agent: 'codex',
          version: '1.0.0',
        ),
      );
      await _seedTaskRun(
        db,
        id: 'command-latest-a',
        runId: 'command-latest',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['runIds'], ['command-latest', 'command-same-kind']);
      expect(source['taskRunCount'], 2);
    },
  );

  test('aggregate-compatible scopes harness-kind compatibility to selected '
      'results in a mixed-harness run', () async {
    await _seedRun(
      db,
      id: 'mixed',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-minimal': {'kind': 'minimal'},
        'harness-template': {
          'kind': 'command-template',
          'agent': 'codex',
          'agentVersion': '1.0.0',
        },
      }),
    );
    await _seedTaskRun(
      db,
      id: 'mixed-minimal-a',
      runId: 'mixed',
      taskId: 'task.a',
      providerId: 'openai',
      harnessId: 'harness-minimal',
    );
    await _seedTaskRun(
      db,
      id: 'mixed-template-a',
      runId: 'mixed',
      taskId: 'task.a',
      providerId: 'anthropic',
      harnessId: 'harness-template',
    );
    await _seedRun(
      db,
      id: 'other-droid',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-droid': {'kind': 'droid', 'agent': 'droid'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'other-droid-a',
      runId: 'other-droid',
      taskId: 'task.a',
      providerId: 'droid-provider',
      harnessId: 'harness-droid',
    );
    await _seedRun(
      db,
      id: 'other-minimal',
      completedAt: DateTime.utc(2026, 5, 3),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-minimal': {'kind': 'minimal'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'other-minimal-a',
      runId: 'other-minimal',
      taskId: 'task.a',
      providerId: 'openai',
      harnessId: 'harness-minimal',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    final source = export['source']! as Map<String, Object?>;
    // The mixed run's minimal results combine with the minimal-only run,
    // but its command-template results (and the unrelated droid run) do
    // not join in, proving minimal never aggregates with
    // command-template/droid even within the same source run.
    expect(source['anchorRunId'], 'other-minimal');
    expect(source['runIds'], ['mixed', 'other-minimal']);
    expect(source['taskRunCount'], 2);
    final providerIds = {
      for (final row
          in (export['models']! as List<Object?>).cast<Map<String, Object?>>())
        row['providerId'],
    };
    expect(providerIds, {'openai'});
  });

  test('aggregate-compatible matches each of a mixed-harness anchor run\'s '
      'groups independently against single-harness candidate runs', () async {
    await _seedRun(
      db,
      id: 'mixed-anchor',
      completedAt: DateTime.utc(2026, 5, 3),
      provenanceJson: _multiHarnessProvenanceJson({
        'h-minimal': {'kind': 'minimal'},
        'h-droid': {'kind': 'droid', 'agent': 'droid'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'mixed-anchor-minimal',
      runId: 'mixed-anchor',
      taskId: 'task.a',
      harnessId: 'h-minimal',
    );
    await _seedTaskRun(
      db,
      id: 'mixed-anchor-droid',
      runId: 'mixed-anchor',
      taskId: 'task.a',
      harnessId: 'h-droid',
    );
    await _seedRun(
      db,
      id: 'other-minimal',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _multiHarnessProvenanceJson({
        'h-minimal': {'kind': 'minimal'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'other-minimal-a',
      runId: 'other-minimal',
      taskId: 'task.a',
      harnessId: 'h-minimal',
    );
    await _seedRun(
      db,
      id: 'other-droid',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _multiHarnessProvenanceJson({
        'h-droid': {'kind': 'droid', 'agent': 'droid'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'other-droid-a',
      runId: 'other-droid',
      taskId: 'task.a',
      harnessId: 'h-droid',
    );
    await _seedRun(
      db,
      id: 'other-template',
      completedAt: DateTime.utc(2026, 4, 30),
      provenanceJson: _multiHarnessProvenanceJson({
        'h-template': {
          'kind': 'command-template',
          'agent': 'codex',
          'agentVersion': '1.0.0',
        },
      }),
    );
    await _seedTaskRun(
      db,
      id: 'other-template-a',
      runId: 'other-template',
      taskId: 'task.a',
      harnessId: 'h-template',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'mixed-anchor');
    expect(source['runIds'], ['mixed-anchor', 'other-droid', 'other-minimal']);
    expect(source['taskRunCount'], 4);
  });

  test('aggregate-compatible treats legacy runs missing agentHarnesses '
      'provenance as minimal-compatible for the same harness id', () async {
    await _seedRun(
      db,
      id: 'legacy-no-provenance',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _weightsProvenanceJson(
        scoringSchemaVersion: 2,
        evaluatorWeights: {'compile': 1.0},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'legacy-no-provenance-a',
      runId: 'legacy-no-provenance',
      taskId: 'task.a',
      harnessId: 'harness-minimal',
    );
    // agentHarnesses is present but has no entry for the harness id this
    // run's task run actually uses: this must stay 'unknown', not fall
    // back to 'minimal', even though it shares a harness id namespace.
    await _seedRun(
      db,
      id: 'declared-unknown',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-other': {'kind': 'droid', 'agent': 'droid'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-unknown-a',
      runId: 'declared-unknown',
      taskId: 'task.a',
      harnessId: 'harness-minimal',
    );
    await _seedRun(
      db,
      id: 'declared-minimal',
      completedAt: DateTime.utc(2026, 5, 3),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-minimal': {'kind': 'minimal'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-minimal-a',
      runId: 'declared-minimal',
      taskId: 'task.a',
      harnessId: 'harness-minimal',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'declared-minimal');
    expect(source['runIds'], ['declared-minimal', 'legacy-no-provenance']);
    expect(source['taskRunCount'], 2);
  });

  test('aggregate-compatible labels a legacy run using the historical fixed '
      "droid harness id as 'droid', not minimal", () async {
    // Predates config.agentHarnesses: only the historical DroidAgentHarness
    // used a fixed 'droid' harness id at that time.
    await _seedRun(
      db,
      id: 'legacy-droid',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _weightsProvenanceJson(
        scoringSchemaVersion: 2,
        evaluatorWeights: {'compile': 1.0},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'legacy-droid-a',
      runId: 'legacy-droid',
      taskId: 'task.a',
      harnessId: 'droid',
    );
    await _seedRun(
      db,
      id: 'declared-droid',
      completedAt: DateTime.utc(2026, 5, 3),
      provenanceJson: _multiHarnessProvenanceJson({
        'droid': {'kind': 'droid', 'agent': 'droid'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-droid-a',
      runId: 'declared-droid',
      taskId: 'task.a',
      harnessId: 'droid',
    );
    // Shares the 'droid' harness id, but is a genuinely-configured minimal
    // harness: must not aggregate with the legacy-droid run.
    await _seedRun(
      db,
      id: 'declared-minimal-droid-id',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _multiHarnessProvenanceJson({
        'droid': {'kind': 'minimal'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-minimal-droid-id-a',
      runId: 'declared-minimal-droid-id',
      taskId: 'task.a',
      harnessId: 'droid',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'declared-droid');
    expect(source['runIds'], ['declared-droid', 'legacy-droid']);
    expect(source['taskRunCount'], 2);
  });

  test('aggregate-compatible preserves a modern minimal harness configured '
      "with the historical 'droid' id as its own kind", () async {
    await _seedRun(
      db,
      id: 'declared-minimal-droid-id',
      completedAt: DateTime.utc(2026, 5, 3),
      provenanceJson: _multiHarnessProvenanceJson({
        'droid': {'kind': 'minimal'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-minimal-droid-id-a',
      runId: 'declared-minimal-droid-id',
      taskId: 'task.a',
      harnessId: 'droid',
    );
    await _seedRun(
      db,
      id: 'declared-minimal-droid-id-2',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _multiHarnessProvenanceJson({
        'droid': {'kind': 'minimal'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-minimal-droid-id-2-a',
      runId: 'declared-minimal-droid-id-2',
      taskId: 'task.a',
      harnessId: 'droid',
    );
    // Legacy provenance with the historical fixed droid harness id must
    // resolve to 'droid', not this run's 'minimal' label.
    await _seedRun(
      db,
      id: 'legacy-droid',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _weightsProvenanceJson(
        scoringSchemaVersion: 2,
        evaluatorWeights: {'compile': 1.0},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'legacy-droid-a',
      runId: 'legacy-droid',
      taskId: 'task.a',
      harnessId: 'droid',
    );
    // A genuine droid harness sharing the same 'droid' harness id must not
    // aggregate with this minimal-labeled run either.
    await _seedRun(
      db,
      id: 'declared-droid',
      completedAt: DateTime.utc(2026, 4, 30),
      provenanceJson: _multiHarnessProvenanceJson({
        'droid': {'kind': 'droid', 'agent': 'droid'},
      }),
    );
    await _seedTaskRun(
      db,
      id: 'declared-droid-a',
      runId: 'declared-droid',
      taskId: 'task.a',
      harnessId: 'droid',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'declared-minimal-droid-id');
    expect(source['runIds'], [
      'declared-minimal-droid-id',
      'declared-minimal-droid-id-2',
    ]);
    expect(source['taskRunCount'], 2);
  });

  test('aggregate-compatible separates command-template scaffolds sharing '
      'kind/agent/version by templateHash', () async {
    for (final entry in [
      ('old', DateTime.utc(2026, 5, 1), 'hash-a'),
      ('latest', DateTime.utc(2026, 5, 2), 'hash-b'),
    ]) {
      await _seedRun(
        db,
        id: 'template-${entry.$1}',
        completedAt: entry.$2,
        provenanceJson: _multiHarnessProvenanceJson({
          'harness-v1': {
            'kind': 'command-template',
            'agent': 'codex',
            'agentVersion': '1.0.0',
            'templateHash': entry.$3,
          },
        }),
      );
      await _seedTaskRun(
        db,
        id: 'template-${entry.$1}-a',
        runId: 'template-${entry.$1}',
        taskId: 'task.a',
      );
    }

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'template-latest',
    ]);
  });

  test('aggregate-compatible does not conflate harness labels for '
      'colon-collision-shaped agent/version values', () async {
    await _seedRun(
      db,
      id: 'collision-a',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-v1': {
          'kind': 'command-template',
          'agent': 'a',
          'agentVersion': 'b:c',
        },
      }),
    );
    await _seedTaskRun(
      db,
      id: 'collision-a-a',
      runId: 'collision-a',
      taskId: 'task.a',
    );
    await _seedRun(
      db,
      id: 'collision-b',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _multiHarnessProvenanceJson({
        'harness-v1': {
          'kind': 'command-template',
          'agent': 'a:b',
          'agentVersion': 'c',
        },
      }),
    );
    await _seedTaskRun(
      db,
      id: 'collision-b-a',
      runId: 'collision-b',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    // A naive delimiter-joined label would produce the identical string
    // 'command-template:a:b:c' for both entries despite representing
    // genuinely different agent/version identities, and would wrongly
    // treat them as aggregation-compatible.
    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'collision-b',
    ]);
  });

  test('aggregate-compatible separates corpus manifest digests', () async {
    await _seedRun(
      db,
      id: 'manifest-old',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _presetProvenanceJson(corpusDigest: 'a'),
    );
    await _seedTaskRun(
      db,
      id: 'manifest-old-a',
      runId: 'manifest-old',
      taskId: 'task.a',
    );
    await _seedRun(
      db,
      id: 'manifest-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _presetProvenanceJson(corpusDigest: 'b'),
    );
    await _seedTaskRun(
      db,
      id: 'manifest-latest-a',
      runId: 'manifest-latest',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'manifest-latest',
    ]);
  });

  test('aggregate-compatible separates incompatible environments', () async {
    final incompatibleRuns = {
      'env-dart': _environmentProvenanceJson(dartVersion: '3.11.3'),
      'env-flutter': _environmentProvenanceJson(flutterVersion: '3.41.5'),
      'env-host': _environmentProvenanceJson(hostPlatform: 'macos'),
      'env-lock': _environmentProvenanceJson(lockDigestChar: 'b'),
    };
    for (final entry in incompatibleRuns.entries) {
      await _seedRun(
        db,
        id: entry.key,
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: entry.value,
      );
      await _seedTaskRun(
        db,
        id: '${entry.key}-a',
        runId: entry.key,
        taskId: 'task.a',
      );
    }
    await _seedRun(
      db,
      id: 'env-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _environmentProvenanceJson(),
    );
    await _seedTaskRun(
      db,
      id: 'env-latest-a',
      runId: 'env-latest',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'env-latest',
    ]);
  });

  test('aggregate-compatible aggregates matching environments', () async {
    await _seedRun(
      db,
      id: 'same-env-old',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _environmentProvenanceJson(dartVersion: '3.11.4'),
    );
    await _seedTaskRun(
      db,
      id: 'same-env-old-a',
      runId: 'same-env-old',
      taskId: 'task.a',
    );
    await _seedRun(
      db,
      id: 'same-env-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _environmentProvenanceJson(dartVersion: '3.11.4'),
    );
    await _seedTaskRun(
      db,
      id: 'same-env-latest-a',
      runId: 'same-env-latest',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'same-env-latest',
      'same-env-old',
    ]);
  });

  test('aggregate-compatible separates command-template versions', () async {
    for (final entry in [
      ('old', DateTime.utc(2026, 5, 1), '1.0.0'),
      ('latest', DateTime.utc(2026, 5, 2), '2.0.0'),
    ]) {
      await _seedRun(
        db,
        id: 'version-${entry.$1}',
        completedAt: entry.$2,
        provenanceJson: _harnessProvenanceJson(
          'command-template',
          agent: 'codex',
          version: entry.$3,
        ),
      );
      await _seedTaskRun(
        db,
        id: 'version-${entry.$1}-a',
        runId: 'version-${entry.$1}',
        taskId: 'task.a',
      );
    }

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'version-latest',
    ]);
  });

  test('aggregate-compatible separates scoring schema versions', () async {
    await _seedRun(
      db,
      id: 'schema-old',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _weightsProvenanceJson(
        evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'schema-old-a',
      runId: 'schema-old',
      taskId: 'task.a',
    );
    await _seedRun(
      db,
      id: 'schema-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _weightsProvenanceJson(
        scoringSchemaVersion: 2,
        evaluatorWeights: {'compile': 1.0},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'schema-latest-a',
      runId: 'schema-latest',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'schema-latest');
    expect(source['runIds'], ['schema-latest']);
    expect(source['taskRunCount'], 1);
    expect(source['warnings'], isEmpty);
  });

  test(
    'aggregate-compatible exports schema-1 anchor scoring metadata',
    () async {
      await _seedRun(
        db,
        id: 'legacy-anchor',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _weightsProvenanceJson(
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'legacy-anchor-a',
        runId: 'legacy-anchor',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['anchorRunId'], 'legacy-anchor');
      final scoring = export['scoring']! as Map<String, Object?>;
      expect(scoring['schemaVersion'], 1);
      expect(scoring.containsKey('diffSizePolicy'), isFalse);
      expect(scoring.containsKey('diagnosticOnlyEvaluatorIds'), isFalse);
    },
  );

  test(
    'aggregate-compatible keeps schema-1 diff_size weights significant',
    () async {
      await _seedRun(
        db,
        id: 'legacy-old',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: _weightsProvenanceJson(
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'legacy-old-a',
        runId: 'legacy-old',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'legacy-latest',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _weightsProvenanceJson(
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.1},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'legacy-latest-a',
        runId: 'legacy-latest',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['anchorRunId'], 'legacy-latest');
      expect(source['runIds'], ['legacy-latest']);
      expect(source['taskRunCount'], 1);
    },
  );

  test(
    'aggregate-compatible ignores schema-2 diagnostic weight differences',
    () async {
      await _seedRun(
        db,
        id: 'diag-old',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: _weightsProvenanceJson(
          scoringSchemaVersion: 2,
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'diag-old-a',
        runId: 'diag-old',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'diag-latest',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _weightsProvenanceJson(
          scoringSchemaVersion: 2,
          evaluatorWeights: {'compile': 1.0},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'diag-latest-a',
        runId: 'diag-latest',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['anchorRunId'], 'diag-latest');
      expect(source['runIds'], ['diag-latest', 'diag-old']);
      expect(source['taskRunCount'], 2);
      expect(source['warnings'], isEmpty);
    },
  );

  test('source includes sanitized run provenance readiness summary', () async {
    await _seedRun(
      db,
      id: 'release-ready',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _completeRunProvenanceJson(),
    );
    await _seedTaskRun(
      db,
      id: 'release-ready-a',
      runId: 'release-ready',
      taskId: 'task.a',
      primaryPass: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    final provenance = source['runProvenance']! as Map<String, Object?>;
    expect(provenance['runCount'], 1);
    expect(provenance['embeddedRunCount'], 1);
    expect(provenance['sandboxEnforcedRunCount'], 1);
    expect(provenance['taskExecutionPolicyRunCount'], 1);
    expect(provenance['networkDisabledTaskPolicyRunCount'], 1);
    expect(provenance['taskResourceLimitRunCount'], 1);
    expect(provenance['sdkVersionRunCount'], 1);
    expect(provenance['dependencySnapshotRunCount'], 1);
    expect(provenance['pricingRegistryRunCount'], 1);
    expect(provenance['generatedCodeSandboxBackends'], ['test-sandbox']);
    expect(provenance['dartVersions'], ['3.11.4']);
    expect(provenance['flutterVersions'], ['3.41.6']);
    expect(provenance['warnings'], isEmpty);
    final environmentIds = provenance['environmentIds']! as List<Object?>;
    expect(environmentIds, hasLength(1));
    expect(environmentIds.single, isA<String>());
    expect((environmentIds.single! as String), hasLength(12));

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('gitCommit')));
    expect(encoded, isNot(contains('/home/dev/private')));
    expect(encoded, isNot(contains('secret-provider-config')));
  });

  test('source rejects legacy polling-only resource enforcement', () async {
    final provenance =
        jsonDecode(_completeRunProvenanceJson()) as Map<String, Object?>;
    final task =
        (provenance['tasks']! as List<Object?>).single as Map<String, Object?>;
    final policy = task['executionPolicy']! as Map<String, Object?>;
    final enforcement = policy['resourceEnforcement']! as Map<String, Object?>;
    enforcement['memoryMb'] = {
      'enforced': true,
      'mechanism': 'rssPolling',
      'kernelEnforced': false,
    };
    enforcement['maxProcesses'] = {
      'enforced': true,
      'mechanism': 'processTreePolling',
      'kernelEnforced': false,
    };
    await _seedRun(
      db,
      id: 'legacy-polling',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: jsonEncode(provenance),
    );
    await _seedTaskRun(
      db,
      id: 'legacy-polling-a',
      runId: 'legacy-polling',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final summary =
        (export['source']! as Map<String, Object?>)['runProvenance']!
            as Map<String, Object?>;
    expect(summary['taskResourceLimitRunCount'], 0);
    expect(
      summary['warnings'],
      contains(
        'Run legacy-polling has incomplete or unenforced task resource limit provenance.',
      ),
    );
  });

  test('latest-run exports only the latest completed run for track', () async {
    await _seedRun(db, id: 'old', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(db, id: 'old-a', runId: 'old', taskId: 'task.a');
    await _seedRun(db, id: 'latest', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(db, id: 'latest-a', runId: 'latest', taskId: 'task.a');
    await _seedRun(
      db,
      id: 'new-codegen',
      completedAt: DateTime.utc(2026, 5, 3),
    );
    await _seedTaskRun(
      db,
      id: 'codegen-a',
      runId: 'new-codegen',
      taskId: 'task.a',
      benchmarkTrack: 'codegen',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'latest');
    expect(source['runIds'], ['latest']);
    expect(source['taskRunCount'], 1);
  });

  test('best-observed selects best task runs and respects run-id', () async {
    await _seedRun(db, id: 'r1', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'r1-fail',
      runId: 'r1',
      taskId: 'task.a',
      primaryPass: false,
      aggregateScore: 0.9,
    );
    await _seedRun(db, id: 'r2', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(
      db,
      id: 'r2-pass',
      runId: 'r2',
      taskId: 'task.a',
      primaryPass: true,
      aggregateScore: 0.7,
    );

    final best = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.bestObserved,
      ),
    );

    expect(
      (best['benchmark']! as Map<String, Object?>)['dataPolicy'],
      'best-observed',
    );
    final bestModel =
        ((best['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(bestModel['passCount'], 1);
    expect((best['source']! as Map<String, Object?>)['runIds'], ['r1', 'r2']);

    final scoped = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.bestObserved,
        runId: 'r1',
      ),
    );

    final scopedModel =
        ((scoped['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(scopedModel['passCount'], 0);
    expect((scoped['source']! as Map<String, Object?>)['runIds'], ['r1']);
  });

  test('model rows include metrics and rank by contract comparator', () async {
    await _seedRun(db, id: 'metrics', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'openai-pass',
      runId: 'metrics',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: true,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'hidden_test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'llm_judge',
      passed: true,
      details: const {
        'judge_overhead': {
          'provider_id': 'openai',
          'model_id': 'gpt-5',
          'prompt_tokens': 100,
          'completion_tokens': 20,
          'estimated_cost_micros': 325,
          'pricing_status': 'exact',
          'pricing_registry_version': '2026-05-31',
          'pricing_currency': 'USD',
        },
      },
    );
    await _seedTaskRun(
      db,
      id: 'openai-fail',
      runId: 'metrics',
      taskId: 'task.b',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-fail',
      evaluatorId: 'hidden_test',
      passed: false,
      details: const {'blocked': true, 'blocked_by': 'test'},
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-pass-a',
      runId: 'metrics',
      taskId: 'task.a',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-a',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-a',
      evaluatorId: 'hidden_test',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-pass-b',
      runId: 'metrics',
      taskId: 'task.b',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2500,
      promptTokens: 20,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-b',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-b',
      evaluatorId: 'hidden_test',
      passed: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['judgeOverhead'], {
      'evaluationCount': 1,
      'promptTokens': 100,
      'completionTokens': 20,
      'knownEstimatedCostCount': 1,
      'unknownEstimatedCostCount': 0,
      'totalEstimatedCostMicros': 325,
      'pricingStatusCounts': {'exact': 1},
    });
    final scoring = export['scoring']! as Map<String, Object?>;
    expect(scoring['schemaVersion'], 2);
    expect(scoring['primaryMetric'], 'primary_pass');
    expect(scoring['rankingMetric'], 'primary_pass_rate');
    expect(scoring['confidenceInterval'], 'wilson_95');
    expect(scoring['diffSizePolicy'], 'diagnostic_only_full_patch');
    expect(scoring['diagnosticOnlyEvaluatorIds'], ['diff_size']);
    final defaultWeights =
        scoring['defaultEvaluatorWeights']! as Map<String, Object?>;
    expect(defaultWeights, isNot(contains('diff_size')));
    expect(
      scoring['failureTags'],
      containsAll(['pass', 'public_tests_failed', 'hidden_verifier_failed']),
    );

    final models = (export['models']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(models.first['providerId'], 'deepseek');
    expect(models.first['rank'], 1);
    expect(models.first['score'], models.first['passRate']);
    expect(models.first['score'], 1.0);

    final openai = models.singleWhere((row) => row['providerId'] == 'openai');
    expect(openai['passCount'], 1);
    expect(openai['sampleCount'], 2);
    expect(openai['passRate'], 0.5);
    expect(openai['trialCount'], 2);
    expect(openai['passAtK'], {
      '1': {'k': 1, 'passCount': 1, 'sampleCount': 2, 'passRate': 0.5},
    });
    expect(openai['confidenceInterval'], isA<Map<String, Object?>>());
    expect(openai['lowSample'], isTrue);
    expect(openai['medianLatencyMs'], 2000);
    expect(openai['medianPromptTokens'], 20);
    expect(openai['medianCompletionTokens'], 30);
    expect(openai['medianEstimatedCostMicros'], 326);
    expect(openai['knownEstimatedCostCount'], 2);
    expect(openai['unknownEstimatedCostCount'], 0);
    expect(openai['totalEstimatedCostMicros'], 651);
    expect(openai['costPerSolvedTaskMicros'], 651);
    expect(openai['cheapestPassingEstimatedCostMicros'], 213);
    expect(openai['publicPassCount'], 1);
    expect(openai['publicSampleCount'], 2);
    expect(openai['publicPassRate'], 0.5);
    expect(openai['hiddenPassCount'], 1);
    expect(openai['hiddenSampleCount'], 1);
    expect(openai['hiddenPassRate'], 1.0);
    expect(openai['blockedEvaluationCount'], 1);
    expect(openai['blockedTaskRunCount'], 1);
    expect(openai['failureBreakdown'], {'pass': 1, 'public_tests_failed': 1});
  });

  test('model config metadata separates effort variants', () async {
    await _seedRun(
      db,
      id: 'model-config',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: jsonEncode({
        'schemaVersion': 1,
        'providers': [
          {
            'id': 'openai',
            'selectedModelConfigs': [
              {
                'modelId': 'gpt-5::low',
                'baseModelId': 'gpt-5',
                'modelConfig': {
                  'effort': 'low',
                  'maxOutputTokens': 16384,
                  'temperature': {
                    'configured': false,
                    'status': 'provider_default',
                  },
                  'toolPolicy': 'none',
                },
              },
              {
                'modelId': 'gpt-5::high',
                'baseModelId': 'gpt-5',
                'modelConfig': {
                  'effort': 'high',
                  'maxOutputTokens': 16384,
                  'temperature': {
                    'configured': false,
                    'status': 'provider_default',
                  },
                  'toolPolicy': 'none',
                },
              },
            ],
          },
        ],
      }),
    );
    await _seedTaskRun(
      db,
      id: 'effort-low',
      runId: 'model-config',
      taskId: 'task.a',
      modelId: 'gpt-5::low',
      trialIndex: 0,
      primaryPass: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'effort-low',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'effort-high',
      runId: 'model-config',
      taskId: 'task.a',
      modelId: 'gpt-5::high',
      trialIndex: 1,
      primaryPass: false,
      failureTag: 'public_tests_failed',
    );
    await _seedEvaluation(
      db,
      taskRunId: 'effort-high',
      evaluatorId: 'test',
      passed: false,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['modelCount'], 2);
    final models = (export['models']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      {for (final row in models) row['modelId']},
      {'gpt-5::low', 'gpt-5::high'},
    );
    final low = models.singleWhere((row) => row['modelId'] == 'gpt-5::low');
    final high = models.singleWhere((row) => row['modelId'] == 'gpt-5::high');
    expect(low['baseModelId'], 'gpt-5');
    expect(low['modelConfig'], {
      'effort': 'low',
      'maxOutputTokens': 16384,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
    });
    expect(high['baseModelId'], 'gpt-5');
    expect(high['modelConfig'], {
      'effort': 'high',
      'maxOutputTokens': 16384,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
    });

    final cells = (export['taskModelCells']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(cells, hasLength(2));
    expect(
      cells.singleWhere((row) => row['modelId'] == 'gpt-5::high'),
      containsPair('modelConfig', {
        'effort': 'high',
        'maxOutputTokens': 16384,
        'temperature': {'configured': false, 'status': 'provider_default'},
        'toolPolicy': 'none',
      }),
    );

    final trials = (export['trialSummaries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      trials.singleWhere((row) => row['modelId'] == 'gpt-5::low'),
      containsPair('modelConfig', {
        'effort': 'low',
        'maxOutputTokens': 16384,
        'temperature': {'configured': false, 'status': 'provider_default'},
        'toolPolicy': 'none',
      }),
    );
  });

  test(
    'task rows aggregate by task/version/track using measured samples',
    () async {
      await _seedRun(db, id: 'tasks', completedAt: DateTime.utc(2026, 5, 1));
      await _seedTaskRun(
        db,
        id: 'task-pass',
        runId: 'tasks',
        taskId: 'task.a',
        primaryPass: true,
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'test',
        passed: true,
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'agent_harness',
        passed: true,
        details: const {
          'steps': ['inspect', 'edit', 'test'],
          'usage': {'peak_context_tokens': 9000},
        },
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'task_hidden',
        passed: true,
      );
      await _seedTaskRun(
        db,
        id: 'task-null',
        runId: 'tasks',
        taskId: 'task.a',
        providerId: 'deepseek',
        modelId: 'deepseek-v4-pro',
        primaryPass: null,
      );
      await _seedTaskRun(
        db,
        id: 'task-fail-v2',
        runId: 'tasks',
        taskId: 'task.a',
        taskVersion: 2,
        primaryPass: false,
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(
          track: 'agentic',
          strategy: LeaderboardExportStrategy.latestRun,
        ),
      );

      final tasks = (export['tasks']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(tasks, hasLength(2));
      expect(tasks.first['taskId'], 'task.a');
      expect(tasks.first['taskVersion'], 1);
      expect(tasks.first['trialCount'], 1);
      expect(tasks.first['sampleCount'], 1);
      expect(tasks.first['modelCount'], 2);
      expect(tasks.first['passRate'], 1.0);
      expect(tasks.first['confidenceInterval'], isA<Map<String, Object?>>());
      expect(tasks.first['medianStepCount'], 3);
      expect(tasks.first['medianPeakContextTokens'], 9000);
      expect(tasks.first['publicPassCount'], 1);
      expect(tasks.first['publicSampleCount'], 1);
      expect(tasks.first['hiddenPassCount'], 1);
      expect(tasks.first['hiddenSampleCount'], 1);
      expect(tasks.first['blockedEvaluationCount'], 0);
      expect(tasks.first['blockedTaskRunCount'], 0);
      expect(tasks.last['taskVersion'], 2);
      expect(tasks.last['passRate'], 0.0);
    },
  );

  test('task-model cells expose sanitized aggregate heatmap data', () async {
    await _seedRun(db, id: 'cells', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'openai-a-pass',
      runId: 'cells',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: true,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-pass',
      evaluatorId: 'agent_harness',
      passed: true,
      details: const {'step_count': 6, 'peak_context_tokens': 12000},
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-pass',
      evaluatorId: 'task_hidden',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'openai-a-fail',
      runId: 'cells',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
      responseText: 'raw response must not leak',
      patchText: 'diff --git a/private b/private',
      trajectoryLogPath: '/home/dev/private/trajectory.log',
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-fail',
      evaluatorId: 'agent_harness',
      passed: true,
      details: const {
        'metadata': {'stepCount': 10, 'peakContextTokens': 16000},
      },
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-fail',
      evaluatorId: 'task_hidden',
      passed: false,
      details: const {'blocked': true, 'blocked_by': 'test'},
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-b-pass',
      runId: 'cells',
      taskId: 'task.b',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 20,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final cells = (export['taskModelCells']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(cells, hasLength(2));

    final openai = cells.singleWhere((row) => row['providerId'] == 'openai');
    expect(openai['modelId'], 'gpt-5');
    expect(openai['taskId'], 'task.a');
    expect(openai['taskVersion'], 1);
    expect(openai['benchmarkTrack'], 'agentic');
    expect(openai['passCount'], 1);
    expect(openai['sampleCount'], 2);
    expect(openai['passRate'], 0.5);
    expect(openai['trialCount'], 2);
    expect(openai['errorCount'], 1);
    expect(openai['passAtK'], {
      '1': {'k': 1, 'passCount': 0, 'sampleCount': 1, 'passRate': 0.0},
      '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
    });
    expect(openai['publicPassCount'], 1);
    expect(openai['publicSampleCount'], 2);
    expect(openai['publicPassRate'], 0.5);
    expect(openai['hiddenPassCount'], 1);
    expect(openai['hiddenSampleCount'], 1);
    expect(openai['hiddenPassRate'], 1.0);
    expect(openai['blockedEvaluationCount'], 1);
    expect(openai['blockedTaskRunCount'], 1);
    expect(openai['medianStepCount'], 8);
    expect(openai['medianPeakContextTokens'], 14000);
    expect(openai['medianLatencyMs'], 2000);
    expect(openai['medianPromptTokens'], 20);
    expect(openai['medianCompletionTokens'], 30);
    expect(openai['medianEstimatedCostMicros'], 326);
    expect(openai['knownEstimatedCostCount'], 2);
    expect(openai['unknownEstimatedCostCount'], 0);
    expect(openai['failureBreakdown'], {'pass': 1, 'public_tests_failed': 1});

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('raw response must not leak')));
    expect(encoded, isNot(contains('diff --git a/private b/private')));
    expect(encoded, isNot(contains('/home/dev/private/trajectory.log')));
  });

  test('exports pass@k and capped sanitized trial summaries', () async {
    await _seedRun(db, id: 'trials', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'trial-fail',
      runId: 'trials',
      taskId: 'task.a',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      trialIndex: 0,
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
      responseText: 'private raw response',
      patchText: 'diff --git private',
      trajectoryLogPath: '/home/dev/private/trial.log',
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-fail',
      evaluatorId: 'agent_harness',
      passed: false,
      details: const {'step_count': 4, 'peak_context_tokens': 8000},
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-fail',
      evaluatorId: 'task_hidden',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'trial-pass',
      runId: 'trials',
      taskId: 'task.a',
      primaryPass: true,
      trialIndex: 1,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-pass',
      evaluatorId: 'agent_harness',
      passed: true,
      details: const {'stepCount': 8, 'peakContextTokens': 12000},
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-pass',
      evaluatorId: 'task_hidden',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'trial-hidden-fail',
      runId: 'trials',
      taskId: 'task.a',
      primaryPass: false,
      failureTag: 'hidden_verifier_failed',
      trialIndex: 2,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 30,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
        trialSummaryLimit: 2,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['trialSummaryCount'], 2);
    expect(source['trialSummaryTotalCount'], 3);
    expect(source['trialSummaryTruncated'], isTrue);
    expect(source['trialSummaryLimit'], 2);

    final model =
        ((export['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(model['trialCount'], 3);
    expect(model['sampleCount'], 3);
    expect(model['medianStepCount'], 6);
    expect(model['medianPeakContextTokens'], 10000);
    expect(model['passAtK'], {
      '1': {'k': 1, 'passCount': 0, 'sampleCount': 1, 'passRate': 0.0},
      '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
      '3': {'k': 3, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
    });

    final cell =
        ((export['taskModelCells']! as List<Object?>).single!
            as Map<String, Object?>);
    expect(cell['passAtK'], model['passAtK']);
    expect(cell['confidenceInterval'], isA<Map<String, Object?>>());
    expect(cell['medianStepCount'], 6);
    expect(cell['medianPeakContextTokens'], 10000);

    final trials = (export['trialSummaries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(trials, hasLength(2));
    expect(trials.first['trialId'], isA<String>());
    expect(trials.first['trialId'].toString(), hasLength(12));
    expect(trials.first['trialIndex'], 0);
    expect(trials.first['primaryPass'], isFalse);
    expect(trials.first['failureTag'], 'public_tests_failed');
    expect(trials.first['publicPassed'], isFalse);
    expect(trials.first['hiddenPassed'], isTrue);
    expect(trials.first['stepCount'], 4);
    expect(trials.first['peakContextTokens'], 8000);
    expect(trials.first['latencyMs'], 3000);
    expect(trials.first['promptTokens'], 30);
    expect(trials.first['completionTokens'], 40);
    expect(trials.first['estimatedCostMicros'], isA<int>());
    expect(trials[1]['trialIndex'], 1);
    expect(trials[1]['primaryPass'], isTrue);
    expect(trials[1]['failureTag'], 'pass');
    expect(trials[1]['stepCount'], 8);
    expect(trials[1]['peakContextTokens'], 12000);

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('private raw response')));
    expect(encoded, isNot(contains('diff --git private')));
    expect(encoded, isNot(contains('/home/dev/private/trial.log')));
  });

  test('public export excludes raw and private task-run fields', () async {
    await _seedRun(db, id: 'safe', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'safe-a',
      runId: 'safe',
      taskId: 'task.a',
      responseText: 'raw prompt secret response',
      patchText: 'diff --git secret patch',
      trajectoryLogPath: '/home/dev/private/trajectory.log',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('raw prompt secret response')));
    expect(encoded, isNot(contains('diff --git secret patch')));
    expect(encoded, isNot(contains('/home/dev/private/trajectory.log')));
  });

  test(
    'malformed provenance fails closed instead of falling back to minimal',
    () async {
      await _seedRun(db, id: 'anchor', completedAt: DateTime.utc(2026, 5, 2));
      await _seedTaskRun(db, id: 'anchor-a', runId: 'anchor', taskId: 'task.a');
      await _seedRun(
        db,
        id: 'malformed',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: '{bad',
      );
      await _seedTaskRun(
        db,
        id: 'malformed-a',
        runId: 'malformed',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      // Malformed provenance does not fail open into harness-kind
      // aggregation compatibility with the anchor: it is labeled 'unknown',
      // which never matches the anchor's cleanly-parsed legacy 'minimal'
      // label, so its task runs are excluded from the aggregate rather than
      // silently trusted.
      expect(source['runIds'], ['anchor']);
      expect(source['taskRunCount'], 1);
    },
  );

  test('wrong-shaped provenance config fails closed instead of falling back '
      'to minimal', () async {
    await _seedRun(db, id: 'anchor', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(db, id: 'anchor-a', runId: 'anchor', taskId: 'task.a');
    // `config` is present but is not an object: this must not be treated
    // as cleanly-parsed legacy provenance.
    await _seedRun(
      db,
      id: 'wrong-shaped-config',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: jsonEncode({'schemaVersion': 1, 'config': 'nope'}),
    );
    await _seedTaskRun(
      db,
      id: 'wrong-shaped-config-a',
      runId: 'wrong-shaped-config',
      taskId: 'task.a',
    );
    // `config.agentHarnesses` is present but is not an object: this must
    // not be treated as either legacy or genuinely-configured provenance.
    await _seedRun(
      db,
      id: 'wrong-shaped-harnesses',
      completedAt: DateTime.utc(2026, 4, 30),
      provenanceJson: jsonEncode({
        'schemaVersion': 1,
        'config': {
          'scoringSchemaVersion': 2,
          'evaluatorWeights': {'compile': 1.0},
          'agentHarnesses': ['not-a-map'],
        },
      }),
    );
    await _seedTaskRun(
      db,
      id: 'wrong-shaped-harnesses-a',
      runId: 'wrong-shaped-harnesses',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['runIds'], ['anchor']);
    expect(source['taskRunCount'], 1);
  });

  test('empty matching result set emits empty JSON with warning', () async {
    await _seedRun(db, id: 'codegen', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'codegen-a',
      runId: 'codegen',
      taskId: 'task.a',
      benchmarkTrack: 'codegen',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['taskRunCount'], 0);
    expect(export['models'], isEmpty);
    expect(export['tasks'], isEmpty);
    expect(source['warnings'].toString(), contains('No completed task runs'));
  });
}

String _completeRunProvenanceJson() {
  return jsonEncode({
    'schemaVersion': 1,
    'config': {
      'evaluatorWeights': {'compile': 1.0},
      'generatedCodeSandbox': {
        'required': true,
        'enforced': true,
        'backend': 'test-sandbox',
      },
      'pricingRegistry': {
        'version': '2026-05-31',
        'currency': 'USD',
        'modelCount': 2,
      },
      'scoringSchemaVersion': 2,
      'providerConfig': 'secret-provider-config',
    },
    'tasks': [
      {
        'id': 'task.a',
        'executionPolicy': {
          'allowInternet': false,
          'resources': {
            'cpus': 2,
            'memoryMb': 8192,
            'maxProcesses': 64,
            'maxOutputBytes': 1048576,
          },
          'resourceEnforcement': _fullyEnforcedResourcePolicy(),
        },
      },
    ],
    'environment': {
      'hostPlatform': 'linux',
      'dartVersion': '3.11.4 (stable)',
      'flutterVersion': '3.41.6',
      'dependencySnapshot': {
        'status': 'present',
        'files': {
          'pubspec.lock': {
            'sha256':
                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            'bytes': 123,
          },
        },
      },
      'gitCommit': 'abcdef',
      'privatePath': '/home/dev/private/project',
    },
  });
}

Map<String, Object?> _fullyEnforcedResourcePolicy() => const {
  'cpus': {'enforced': true, 'mechanism': 'cpuQuota', 'kernelEnforced': true},
  'memoryMb': {
    'enforced': true,
    'mechanism': 'memoryLimit',
    'kernelEnforced': true,
  },
  'maxProcesses': {
    'enforced': true,
    'mechanism': 'processLimit',
    'kernelEnforced': true,
  },
  'maxOutputBytes': {
    'enforced': true,
    'mechanism': 'boundedOutputCapture',
    'kernelEnforced': false,
  },
};

Future<void> _seedRun(
  AppDatabase db, {
  required String id,
  required DateTime completedAt,
  String provenanceJson =
      '{"schemaVersion":1,"config":{"scoringSchemaVersion":2,"evaluatorWeights":{"compile":1.0}}}',
}) async {
  await db
      .into(db.runs)
      .insert(
        RunsCompanion.insert(
          id: id,
          startedAt: completedAt.subtract(const Duration(minutes: 5)),
          completedAt: Value(completedAt),
          provenanceJson: Value(provenanceJson),
        ),
      );
}

String _weightsProvenanceJson({
  int? scoringSchemaVersion,
  required Map<String, Object?> evaluatorWeights,
}) {
  return jsonEncode({
    'schemaVersion': 1,
    'config': {
      if (scoringSchemaVersion != null)
        'scoringSchemaVersion': scoringSchemaVersion,
      'evaluatorWeights': evaluatorWeights,
    },
  });
}

String _harnessProvenanceJson(String kind, {String? agent, String? version}) =>
    jsonEncode({
      'schemaVersion': 1,
      'config': {
        'scoringSchemaVersion': 2,
        'evaluatorWeights': {'compile': 1.0},
        'agentHarnesses': {
          'harness-v1': {
            'kind': kind,
            if (agent != null) 'agent': agent,
            if (version != null) 'agentVersion': version,
          },
        },
      },
    });

String _multiHarnessProvenanceJson(
  Map<String, Map<String, Object?>> agentHarnesses,
) => jsonEncode({
  'schemaVersion': 1,
  'config': {
    'scoringSchemaVersion': 2,
    'evaluatorWeights': {'compile': 1.0},
    'agentHarnesses': agentHarnesses,
  },
});

String _environmentProvenanceJson({
  String dartVersion = '3.11.4',
  String flutterVersion = '3.41.6',
  String hostPlatform = 'linux',
  String lockDigestChar = 'a',
}) => jsonEncode({
  'schemaVersion': 2,
  'config': {
    'scoringSchemaVersion': 2,
    'evaluatorWeights': {'compile': 1.0},
  },
  'environment': {
    'hostPlatform': hostPlatform,
    'dartVersion': dartVersion,
    'flutterVersion': flutterVersion,
    'dependencySnapshot': {
      'status': 'present',
      'files': {
        'pubspec.lock': {
          'sha256': List.filled(64, lockDigestChar).join(),
          'bytes': 123,
        },
      },
    },
  },
});

String _presetProvenanceJson({
  String corpusDigest = 'c',
  bool includeTaskB = true,
}) => jsonEncode({
  'schemaVersion': 2,
  'config': {
    'scoringSchemaVersion': 2,
    'evaluatorWeights': {'compile': 1.0},
    'corpusManifest': {
      'preset': 'mvp',
      'tasks': [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'taskBundleDigest': List.filled(64, 'a').join(),
        },
        if (includeTaskB)
          {
            'taskId': 'task.b',
            'taskVersion': 1,
            'taskBundleDigest': List.filled(64, 'b').join(),
          },
      ],
      'digestSha256': List.filled(64, corpusDigest).join(),
    },
  },
});

Future<void> _seedTaskRun(
  AppDatabase db, {
  required String id,
  required String runId,
  required String taskId,
  String providerId = 'openai',
  String modelId = 'gpt-5',
  int taskVersion = 1,
  String benchmarkTrack = 'agentic',
  String? harnessId = 'harness-v1',
  bool? primaryPass = true,
  String? failureTag,
  int latencyMs = 1000,
  int? promptTokens = 10,
  int? completionTokens = 20,
  double aggregateScore = 1.0,
  String responseText = '',
  String? patchText,
  String? trajectoryLogPath,
  int trialIndex = 0,
  DateTime? completedAt,
}) async {
  await db
      .into(db.taskRuns)
      .insert(
        TaskRunsCompanion.insert(
          id: id,
          runId: runId,
          providerId: providerId,
          modelId: modelId,
          taskId: taskId,
          responseText: responseText,
          latencyMs: latencyMs,
          aggregateScore: aggregateScore,
          completedAt: completedAt ?? DateTime.utc(2026, 5, 1, 12),
          promptTokens: Value(promptTokens),
          completionTokens: Value(completionTokens),
          trialIndex: Value(trialIndex),
          taskVersion: Value(taskVersion),
          benchmarkTrack: Value(benchmarkTrack),
          harnessId: Value(harnessId),
          primaryPass: Value(primaryPass),
          failureTag: Value(failureTag),
          patchText: Value(patchText),
          trajectoryLogPath: Value(trajectoryLogPath),
        ),
      );
}

Future<void> _seedEvaluation(
  AppDatabase db, {
  required String taskRunId,
  required String evaluatorId,
  required bool passed,
  Map<String, Object?> details = const {},
}) async {
  await db
      .into(db.evaluations)
      .insert(
        EvaluationsCompanion.insert(
          id: '$taskRunId-$evaluatorId',
          taskRunId: taskRunId,
          evaluatorId: evaluatorId,
          passed: passed,
          score: passed ? 1.0 : 0.0,
          detailsJson: jsonEncode(details),
        ),
      );
}

Future<({Uri uri, Map<String, Object?> decoded})>
_loadLeaderboardFixtureManifest() async {
  final exporterUri = await Isolate.resolvePackageUri(
    Uri.parse('package:dart_arena/export/leaderboard_exporter.dart'),
  );
  if (exporterUri == null) {
    throw StateError('Could not resolve the dart_arena package location.');
  }
  final manifestUri = exporterUri.resolve(
    '../../../fixtures/leaderboard/compatibility/v1/manifest.v1.json',
  );
  final bytes = await File.fromUri(manifestUri).readAsBytes();
  final decoded = _objectMap(jsonDecode(utf8.decode(bytes)));
  expect(decoded['fixtureManifestVersion'], 1);
  expect(decoded['artifactFamily'], 'leaderboard.v1.json');
  expect(decoded['supportedArtifactSchemaVersions'], [1, 2]);
  return (uri: manifestUri, decoded: decoded);
}

List<Map<String, Object?>> _fixtureEntries(Map<String, Object?> manifest) =>
    _objectList(manifest['entries']);

Map<String, Object?>? _normalizeLeaderboardFixture(String text) {
  try {
    final value = jsonDecode(text);
    if (value is! Map) return null;
    final artifact = _objectMap(value);
    final schemaVersionValue = artifact['schemaVersion'];
    if (!_isNonNegativeInteger(schemaVersionValue)) return null;
    final schemaVersion = (schemaVersionValue as num).toInt();
    if (schemaVersion != 1 && schemaVersion != 2) return null;
    if (artifact['benchmark'] is! Map || artifact['source'] is! Map) {
      return null;
    }
    if (artifact['models'] is! List || artifact['tasks'] is! List) return null;

    final benchmark = _objectMap(artifact['benchmark']);
    final source = _objectMap(artifact['source']);
    final title = benchmark['title'];
    final track = benchmark['track'];
    final dataPolicy = benchmark['dataPolicy'];
    final taskCount = source['taskCount'];
    final taskRunCount = source['taskRunCount'];
    if (!_isNonEmptyString(title) ||
        !_isNonEmptyString(track) ||
        !_leaderboardDataPolicies.contains(dataPolicy) ||
        !_isNonNegativeInteger(taskCount) ||
        !_isNonNegativeInteger(taskRunCount)) {
      return null;
    }

    final models = _objectList(artifact['models']);
    final tasks = _objectList(artifact['tasks']);
    final scoring = _objectMap(artifact['scoring']);
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'generatedAt': _nullableString(artifact['generatedAt']),
      'benchmark': <String, Object?>{
        'title': title,
        'version': _nullableString(benchmark['version']),
        'taskSetId': _nullableString(benchmark['taskSetId']),
        'evaluatorSchemaVersion':
            _finiteNumber(benchmark['evaluatorSchemaVersion']) ?? 0,
        'track': track,
        'dataPolicy': dataPolicy,
        'preset': _nullableString(benchmark['preset']),
        'selectedTasks': [
          for (final task in _objectList(benchmark['selectedTasks']))
            <String, Object?>{
              'taskId': _stringOr(task['taskId'], 'unknown-task'),
              'taskVersion': _stringOrNumber(task['taskVersion']),
              'taskBundleDigest': _nullableString(task['taskBundleDigest']),
            },
        ],
        'corpusManifestDigestSha256': _nullableString(
          benchmark['corpusManifestDigestSha256'],
        ),
      },
      'source': <String, Object?>{
        'anchorRunId': _nullableString(source['anchorRunId']),
        'runIds': _stringList(source['runIds']),
        'taskCount': taskCount,
        'taskRunCount': taskRunCount,
        'modelCount': _finiteNumber(source['modelCount']) ?? models.length,
      },
      'scoring': <String, Object?>{
        'schemaVersion': _finiteNumber(scoring['schemaVersion']) ?? 0,
        'primaryMetric': _nullableString(scoring['primaryMetric']),
        'rankingMetric': _nullableString(scoring['rankingMetric']),
      },
      'models': [for (final model in models) _projectModel(model)],
      'tasks': [for (final task in tasks) _projectTask(task)],
      'taskModelCells': [
        for (final cell in _objectList(artifact['taskModelCells']))
          _projectTaskModelCell(cell),
      ],
      'trialSummaries': [
        for (final trial in _objectList(artifact['trialSummaries']))
          _projectTrialSummary(trial),
      ],
    };
  } on Object {
    return null;
  }
}

Map<String, Object?> _projectModel(Map<String, Object?> model) => {
  'providerId': _stringOr(model['providerId'], 'unknown-provider'),
  'modelId': _stringOr(model['modelId'], 'unknown-model'),
  'rank': _finiteNumber(model['rank']),
  'score': _finiteNumber(model['score']),
  'passRate': _finiteNumber(model['passRate']),
  'trialCount':
      _finiteNumber(model['trialCount']) ??
      _finiteNumber(model['sampleCount']) ??
      0,
  'passCount': _finiteNumber(model['passCount']) ?? 0,
  'sampleCount': _finiteNumber(model['sampleCount']) ?? 0,
};

Map<String, Object?> _projectTask(Map<String, Object?> task) => {
  'taskId': _stringOr(task['taskId'], 'unknown-task'),
  'taskVersion': _stringOrNumber(task['taskVersion']),
  'taskBundleDigest': _nullableString(task['taskBundleDigest']),
  'benchmarkTrack': _nullableString(task['benchmarkTrack']),
  'trialCount':
      _finiteNumber(task['trialCount']) ??
      _finiteNumber(task['sampleCount']) ??
      0,
  'sampleCount': _finiteNumber(task['sampleCount']) ?? 0,
  'modelCount': _finiteNumber(task['modelCount']) ?? 0,
  'passRate': _finiteNumber(task['passRate']),
};

Map<String, Object?> _projectTaskModelCell(Map<String, Object?> cell) => {
  'providerId': _stringOr(cell['providerId'], 'unknown-provider'),
  'modelId': _stringOr(cell['modelId'], 'unknown-model'),
  'taskId': _stringOr(cell['taskId'], 'unknown-task'),
  'taskVersion': _stringOrNumber(cell['taskVersion']),
  'benchmarkTrack': _nullableString(cell['benchmarkTrack']),
  'trialCount':
      _finiteNumber(cell['trialCount']) ??
      _finiteNumber(cell['sampleCount']) ??
      0,
  'passCount': _finiteNumber(cell['passCount']) ?? 0,
  'sampleCount': _finiteNumber(cell['sampleCount']) ?? 0,
  'passRate': _finiteNumber(cell['passRate']),
  'errorCount': _finiteNumber(cell['errorCount']) ?? 0,
};

Map<String, Object?> _projectTrialSummary(Map<String, Object?> trial) => {
  'trialId': _stringOr(trial['trialId'], 'unknown-trial'),
  'runId': _stringOr(trial['runId'], 'unknown-run'),
  'providerId': _stringOr(trial['providerId'], 'unknown-provider'),
  'modelId': _stringOr(trial['modelId'], 'unknown-model'),
  'taskId': _stringOr(trial['taskId'], 'unknown-task'),
  'taskVersion': _stringOrNumber(trial['taskVersion']),
  'benchmarkTrack': _nullableString(trial['benchmarkTrack']),
  'trialIndex': _finiteNumber(trial['trialIndex']) ?? 0,
  'completedAt': _nullableString(trial['completedAt']),
  'primaryPass': trial['primaryPass'] is bool ? trial['primaryPass'] : null,
  'failureTag': _stringOr(trial['failureTag'], 'unknown'),
  'aggregateScore': _finiteNumber(trial['aggregateScore']),
};

const _leaderboardDataPolicies = {
  'aggregate-compatible',
  'latest-run',
  'best-observed',
};

bool _isNonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty;

bool _isNonNegativeInteger(Object? value) =>
    value is num && value.isFinite && value >= 0 && value == value.truncate();

String? _nullableString(Object? value) => value is String ? value : null;

Object? _stringOrNumber(Object? value) =>
    value is String || value is num ? value : null;

String _stringOr(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

num? _finiteNumber(Object? value) =>
    value is num && value.isFinite ? value : null;

List<String> _stringList(Object? value) => value is List
    ? [
        for (final entry in value)
          if (entry is String) entry,
      ]
    : const [];

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (entry is Map) _objectMap(entry),
  ];
}
