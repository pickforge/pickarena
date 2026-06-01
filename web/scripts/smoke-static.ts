import { readFile, stat } from 'node:fs/promises';
import { dirname, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const webRoot = resolve(scriptDir, '..');
const repoRoot = resolve(webRoot, '..');
const buildRoot = resolve(webRoot, 'build');

const indexPath = resolve(buildRoot, 'index.html');
const leaderboardPath = resolve(buildRoot, 'data', 'leaderboard.v1.json');
const requiredBrandingAssets = [
  'dart_arena_logo_horizontal_light.png',
  'dart_arena_mark.png',
  'pickforge_logo.png',
  'pickforge_mark.png'
];
const requiredAnchors = ['leaderboard', 'tasks', 'methodology'];
const publicTitle = 'Dart Arena by Pickforge';

async function main(): Promise<void> {
  await assertFileExists(indexPath);
  await assertFileExists(leaderboardPath);
  await assertValidJson(leaderboardPath);

  for (const asset of requiredBrandingAssets) {
    await assertFileExists(resolve(buildRoot, 'branding', asset));
  }

  const html = await readFile(indexPath, 'utf8');
  assertHtmlIncludes(html, publicTitle, `public title text "${publicTitle}"`);
  assertHtmlIncludes(html, '_app/', 'SvelteKit client asset references');

  for (const anchor of requiredAnchors) {
    assertHtmlIncludes(html, `id="${anchor}"`, `section anchor #${anchor}`);
  }

  assertNoVisibleRenderingArtifacts(html);

  console.log('Static smoke passed:');
  console.log(`- ${repoRelative(indexPath)}`);
  console.log(`- ${repoRelative(leaderboardPath)}`);
  console.log(
    `- ${requiredBrandingAssets
      .map((asset) => repoRelative(resolve(buildRoot, 'branding', asset)))
      .join(', ')}`
  );
}

async function assertFileExists(filePath: string): Promise<void> {
  const stats = await stat(filePath).catch(() => null);
  if (!stats?.isFile()) {
    throw new Error(`Missing required file: ${repoRelative(filePath)}`);
  }
}

async function assertValidJson(filePath: string): Promise<void> {
  const content = await readFile(filePath, 'utf8');

  try {
    JSON.parse(content);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Invalid JSON in ${repoRelative(filePath)}: ${message}`);
  }
}

function assertHtmlIncludes(html: string, expected: string, label: string): void {
  if (!html.includes(expected)) {
    throw new Error(`Missing ${label} in ${repoRelative(indexPath)}`);
  }
}

function assertNoVisibleRenderingArtifacts(html: string): void {
  const visibleText = visibleHtmlText(html);
  const artifacts = [
    { label: 'undefined', pattern: /\bundefined\b/i },
    { label: '[object Object]', pattern: /\[object Object\]/ },
    { label: 'standalone null', pattern: /\bnull\b/i }
  ];

  for (const artifact of artifacts) {
    if (artifact.pattern.test(visibleText)) {
      throw new Error(
        `Visible HTML text contains unresolved rendering artifact: ${artifact.label}`
      );
    }
  }
}

function visibleHtmlText(html: string): string {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<template\b[^>]*>[\s\S]*?<\/template>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&(?:nbsp|#160);/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function repoRelative(filePath: string): string {
  return relative(repoRoot, filePath).split(sep).join('/');
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Static smoke failed: ${message}`);
  process.exit(1);
});
