import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const manifestPath = fileURLToPath(
  new URL(
    '../fixtures/leaderboard/compatibility/v1/manifest.v1.json',
    import.meta.url
  )
);
const manifest = JSON.parse(await readFile(manifestPath, 'utf8')) as {
  entries: { file: string; sha256: string }[];
};

for (const entry of manifest.entries) {
  const bytes = await readFile(resolve(dirname(manifestPath), entry.file));
  entry.sha256 = createHash('sha256').update(bytes).digest('hex');
}

await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
