import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { describe, expect, test, vi } from 'vitest';

import {
  acceptedDataPolicies,
  parseLeaderboardArtifact,
  supportedArtifactSchemaVersions,
  type LeaderboardData
} from '../src/lib/data/leaderboard-contract';

vi.mock('$app/paths', () => ({ base: '' }));
const { loadLeaderboard } = await import('../src/lib/data/leaderboard');

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
  acceptedDataPolicies: string[];
  entries: FixtureEntry[];
};

const manifestPath = fileURLToPath(
  new URL(
    '../../fixtures/leaderboard/compatibility/v1/manifest.v1.json',
    import.meta.url
  )
);
const fixtureDirectory = dirname(manifestPath);
const manifestBytes = await readFile(manifestPath);
const manifest = JSON.parse(manifestBytes.toString('utf8')) as FixtureManifest;

describe('leaderboard compatibility corpus', () => {
  test('uses the versioned manifest and runtime contract constants', () => {
    expect(manifest.fixtureManifestVersion).toBe(1);
    expect(manifest.artifactFamily).toBe('leaderboard.v1.json');
    expect(manifest.supportedArtifactSchemaVersions).toEqual([
      ...supportedArtifactSchemaVersions
    ]);
    expect(manifest.acceptedDataPolicies).toEqual([...acceptedDataPolicies]);
    expect(manifest.entries.length).toBeGreaterThan(0);
  });

  test('lists every fixture exactly once and every listed fixture exists', async () => {
    const files = (await readdir(fixtureDirectory))
      .filter((file) => file !== 'manifest.v1.json')
      .sort();
    const listed = manifest.entries.map((entry) => entry.file).sort();
    expect(listed).toEqual(files);
    expect(new Set(listed).size).toBe(listed.length);
    await Promise.all(
      listed.map((file) => readFile(resolve(fixtureDirectory, file)))
    );
  });

  for (const entry of manifest.entries) {
    test(entry.id, async () => {
      const fixturePath = resolve(fixtureDirectory, entry.file);
      const bytes = await readFile(fixturePath);
      expect(createHash('sha256').update(bytes).digest('hex')).toBe(entry.sha256);

      const parsed = parseLeaderboardArtifact(bytes.toString('utf8'));
      expect(parsed === null ? 'reject' : 'accept').toBe(entry.outcome);
      expect(parsed === null ? null : normalizedProjection(parsed)).toEqual(
        entry.normalizedProjection
      );
    });
  }

  test('preserves fixture ordering in every current collection', () => {
    const current = manifest.entries.find((entry) => entry.id === 'current-v2');
    if (!current || current.outcome !== 'accept') throw new Error('missing current-v2');
    const projection = current.normalizedProjection as LeaderboardData;
    expect(projection.models.map((row) => `${row.providerId}:${row.modelId}`)).toEqual([
      'deepseek:deepseek-v4-pro',
      'openai:gpt-5'
    ]);
    expect(projection.tasks.map((row) => row.taskId)).toEqual(['task.a', 'task.b']);
    expect(
      projection.taskModelCells.map(
        (row) => `${row.providerId}:${row.modelId}:${row.taskId}`
      )
    ).toEqual([
      'deepseek:deepseek-v4-pro:task.a',
      'deepseek:deepseek-v4-pro:task.b',
      'openai:gpt-5:task.a',
      'openai:gpt-5:task.b'
    ]);
    expect(
      projection.trialSummaries.map(
        (row) => `${row.providerId}:${row.modelId}:${row.taskId}:${row.trialIndex}`
      )
    ).toEqual([
      'deepseek:deepseek-v4-pro:task.a:0',
      'deepseek:deepseek-v4-pro:task.b:1',
      'openai:gpt-5:task.a:0',
      'openai:gpt-5:task.b:1'
    ]);
  });
});

describe('leaderboard runtime loader warnings', () => {
  test('preserves the load warning for malformed JSON syntax', async () => {
    const result = await loadLeaderboard(async () => new Response('{', { status: 200 }));
    expect(result.warning).toBe('Leaderboard data could not be loaded.');
  });

  test('uses the malformed warning for a decoded schema error', async () => {
    const result = await loadLeaderboard(
      async () => new Response('{"schemaVersion":2}', { status: 200 })
    );
    expect(result.warning).toBe('Leaderboard data is malformed.');
  });

  test('preserves the load warning for a fetch failure', async () => {
    const result = await loadLeaderboard(async () => {
      throw new Error('offline');
    });
    expect(result.warning).toBe('Leaderboard data could not be loaded.');
  });
});

function normalizedProjection(value: LeaderboardData): LeaderboardData {
  return value;
}
