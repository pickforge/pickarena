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
  'pickarena-lockup-horizontal.png',
  'pickarena-mark-raster.png',
  'pickforge_logo.png',
  'pickforge_mark.png'
];
const requiredAnchors = ['leaderboard'];
const requiredRoutePages = ['methodology', 'tasks', 'run'];
const publicTitle = 'PickArena by Pickforge Studio';
const basePath = normalizeBasePath(process.env.PUBLIC_BASE_PATH ?? '');
const appAssetPath = `${basePath}/_app/`;
const brandingAssetPath = `${basePath}/branding/`;
const leaderboardDataUrl = `${basePath}/data/leaderboard.v1.json`;
const homeHref = `${basePath}/`;

async function main(): Promise<void> {
  await assertFileExists(indexPath);
  await assertFileExists(leaderboardPath);
  await assertValidJson(leaderboardPath);

  for (const asset of requiredBrandingAssets) {
    await assertFileExists(resolve(buildRoot, 'branding', asset));
  }

  const html = await readFile(indexPath, 'utf8');
  assertHtmlIncludes(html, publicTitle, `public title text "${publicTitle}"`);
  assertHtmlIncludes(html, appAssetPath, `SvelteKit asset path "${appAssetPath}"`);
  assertHtmlIncludes(
    html,
    brandingAssetPath,
    `branding asset path "${brandingAssetPath}"`
  );
  assertHtmlIncludes(
    html,
    `data-url="${leaderboardDataUrl}"`,
    `leaderboard fetch URL "${leaderboardDataUrl}"`
  );
  assertHtmlIncludes(html, `href="${homeHref}"`, `home link "${homeHref}"`);
  assertHtmlExcludes(html, './_app/', 'relative SvelteKit asset references');

  if (basePath.length > 0) {
    assertNoRootRelativeRenderedUrls(html, basePath);
  }

  for (const anchor of requiredAnchors) {
    assertHtmlIncludes(html, `id="${anchor}"`, `section anchor #${anchor}`);
  }

  assertNoVisibleRenderingArtifacts(html);

  for (const route of requiredRoutePages) {
    const routePath = resolve(buildRoot, route, 'index.html');
    await assertFileExists(routePath);
    const routeHtml = await readFile(routePath, 'utf8');
    if (!routeHtml.includes(publicTitle)) {
      throw new Error(`Missing public title in ${repoRelative(routePath)}`);
    }
    if (!routeHtml.includes(appAssetPath)) {
      throw new Error(`Missing SvelteKit asset path in ${repoRelative(routePath)}`);
    }
    assertNoVisibleRenderingArtifacts(routeHtml);
  }

  console.log('Static smoke passed:');
  console.log(`- base path: ${basePath || '(root)'}`);
  console.log(`- ${repoRelative(indexPath)}`);
  console.log(`- route pages: ${requiredRoutePages.join(', ')}`);
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

function assertHtmlExcludes(html: string, unexpected: string, label: string): void {
  if (html.includes(unexpected)) {
    throw new Error(`Found ${label} in ${repoRelative(indexPath)}`);
  }
}

function assertNoRootRelativeRenderedUrls(html: string, basePath: string): void {
  const allowedPrefix = escapeRegExp(`${basePath.slice(1)}/`);
  const rootRelativeAttributes = [
    {
      label: 'root-relative href',
      pattern: new RegExp(`\\bhref="/(?!${allowedPrefix})[^"]*"`, 'g')
    },
    {
      label: 'root-relative src',
      pattern: new RegExp(`\\bsrc="/(?!${allowedPrefix})[^"]*"`, 'g')
    },
    {
      label: 'root-relative data URL',
      pattern: new RegExp(`\\bdata-url="/(?!${allowedPrefix})[^"]*"`, 'g')
    }
  ];

  for (const attribute of rootRelativeAttributes) {
    assertNoHtmlMatches(html, attribute.pattern, attribute.label);
  }
}

function assertNoHtmlMatches(html: string, pattern: RegExp, label: string): void {
  const matches = html.match(pattern);
  if (matches && matches.length > 0) {
    throw new Error(
      `Found ${label} in ${repoRelative(indexPath)}: ${matches
        .slice(0, 3)
        .join(', ')}`
    );
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

function normalizeBasePath(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed === '/') return '';

  const withLeadingSlash = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  return withLeadingSlash.endsWith('/')
    ? withLeadingSlash.slice(0, -1)
    : withLeadingSlash;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Static smoke failed: ${message}`);
  process.exit(1);
});
