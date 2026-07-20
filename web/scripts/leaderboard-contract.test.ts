import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { describe, expect, test } from 'bun:test';

import {
  parseLeaderboardArtifact,
  type LeaderboardData
} from '../src/lib/data/leaderboard-contract';

type FixtureEntry = {
  id: string;
  file: string;
  sha256: string;
  outcome: 'accept' | 'reject';
  normalizedProjection: unknown;
};

type FixtureManifest = {
  fixtureManifestVersion: number;
  artifactFamily: string;
  supportedArtifactSchemaVersions: number[];
  entries: FixtureEntry[];
};

const manifestPath = fileURLToPath(
  new URL('../../fixtures/leaderboard/compatibility/v1/manifest.v1.json', import.meta.url)
);
const manifestBytes = await readFile(manifestPath);
const manifest = JSON.parse(manifestBytes.toString('utf8')) as FixtureManifest;

describe('leaderboard compatibility corpus', () => {
  test('uses the versioned manifest', () => {
    expect(manifest.fixtureManifestVersion).toBe(1);
    expect(manifest.artifactFamily).toBe('leaderboard.v1.json');
    expect(manifest.supportedArtifactSchemaVersions).toEqual([1, 2]);
    expect(manifest.entries.length).toBeGreaterThan(0);
  });

  for (const entry of manifest.entries) {
    test(entry.id, async () => {
      const fixturePath = resolve(dirname(manifestPath), entry.file);
      const bytes = await readFile(fixturePath);
      expect(createHash('sha256').update(bytes).digest('hex')).toBe(entry.sha256);

      const parsed = parseLeaderboardArtifact(bytes.toString('utf8'));
      expect(parsed === null ? 'reject' : 'accept').toBe(entry.outcome);
      expect(parsed === null ? null : normalizedProjection(parsed)).toEqual(
        entry.normalizedProjection
      );
    });
  }
});

function normalizedProjection(value: LeaderboardData): unknown {
  return {
    schemaVersion: value.schemaVersion,
    generatedAt: value.generatedAt,
    benchmark: {
      title: value.benchmark.title,
      version: value.benchmark.version,
      taskSetId: value.benchmark.taskSetId,
      evaluatorSchemaVersion: value.benchmark.evaluatorSchemaVersion,
      track: value.benchmark.track,
      dataPolicy: value.benchmark.dataPolicy,
      preset: value.benchmark.preset,
      selectedTasks: value.benchmark.selectedTasks,
      corpusManifestDigestSha256: value.benchmark.corpusManifestDigestSha256
    },
    source: {
      anchorRunId: value.source.anchorRunId,
      runIds: value.source.runIds,
      taskCount: value.source.taskCount,
      taskRunCount: value.source.taskRunCount,
      modelCount: value.source.modelCount
    },
    scoring: {
      schemaVersion: value.scoring.schemaVersion,
      primaryMetric: value.scoring.primaryMetric,
      rankingMetric: value.scoring.rankingMetric
    },
    models: value.models.map((model) => ({
      providerId: model.providerId,
      modelId: model.modelId,
      rank: model.rank,
      score: model.score,
      passRate: model.passRate,
      trialCount: model.trialCount,
      passCount: model.passCount,
      sampleCount: model.sampleCount
    })),
    tasks: value.tasks.map((task) => ({
      taskId: task.taskId,
      taskVersion: task.taskVersion,
      taskBundleDigest: task.taskBundleDigest,
      benchmarkTrack: task.benchmarkTrack,
      trialCount: task.trialCount,
      sampleCount: task.sampleCount,
      modelCount: task.modelCount,
      passRate: task.passRate
    })),
    taskModelCells: value.taskModelCells.map((cell) => ({
      providerId: cell.providerId,
      modelId: cell.modelId,
      taskId: cell.taskId,
      taskVersion: cell.taskVersion,
      benchmarkTrack: cell.benchmarkTrack,
      trialCount: cell.trialCount,
      passCount: cell.passCount,
      sampleCount: cell.sampleCount,
      passRate: cell.passRate,
      errorCount: cell.errorCount
    })),
    trialSummaries: value.trialSummaries.map((trial) => ({
      trialId: trial.trialId,
      runId: trial.runId,
      providerId: trial.providerId,
      modelId: trial.modelId,
      taskId: trial.taskId,
      taskVersion: trial.taskVersion,
      benchmarkTrack: trial.benchmarkTrack,
      trialIndex: trial.trialIndex,
      completedAt: trial.completedAt,
      primaryPass: trial.primaryPass,
      failureTag: trial.failureTag,
      aggregateScore: trial.aggregateScore
    }))
  };
}
