import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { access, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);
const siteRoot = path.join(repositoryRoot, 'dist', 'site');
const hydrationErrorPattern =
  /hydration|hydrating|server html|did not match|minified react error #\d+/i;
const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.gif', 'image/gif'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.jpeg', 'image/jpeg'],
  ['.jpg', 'image/jpeg'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.map', 'application/json; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.ttf', 'font/ttf'],
  ['.wasm', 'application/wasm'],
  ['.webp', 'image/webp'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2'],
]);

function isInsideSite(candidate) {
  const relative = path.relative(siteRoot, candidate);
  return (
    relative === '' ||
    (!relative.startsWith('..') && !path.isAbsolute(relative))
  );
}

async function resolveSiteFile(requestPath) {
  let decodedPath;
  try {
    decodedPath = decodeURIComponent(requestPath);
  } catch {
    return undefined;
  }

  const relativePath = decodedPath.replace(/^\/+/, '');
  let candidate = path.resolve(siteRoot, relativePath);
  if (!isInsideSite(candidate)) return undefined;

  let candidateStat;
  try {
    candidateStat = await stat(candidate);
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }

  if (candidateStat?.isDirectory()) {
    candidate = path.join(candidate, 'index.html');
  } else if (!candidateStat && path.extname(candidate) === '') {
    candidate = path.join(candidate, 'index.html');
  }

  if (!isInsideSite(candidate)) return undefined;

  try {
    const fileStat = await stat(candidate);
    return fileStat.isFile()
      ? { filePath: candidate, size: fileStat.size }
      : undefined;
  } catch (error) {
    if (error?.code === 'ENOENT') return undefined;
    throw error;
  }
}

async function startStaticServer() {
  await access(path.join(siteRoot, 'index.html'));

  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://127.0.0.1');
      const resolved = await resolveSiteFile(url.pathname);
      if (!resolved) {
        response.writeHead(404, {
          'content-type': 'text/plain; charset=utf-8',
        });
        response.end('Not found');
        return;
      }

      response.writeHead(200, {
        'cache-control': 'no-store',
        'content-length': resolved.size,
        'content-type':
          contentTypes.get(path.extname(resolved.filePath).toLowerCase()) ??
          'application/octet-stream',
      });
      if (request.method === 'HEAD') {
        response.end();
        return;
      }
      createReadStream(resolved.filePath).pipe(response);
    } catch (error) {
      response.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' });
      response.end(error instanceof Error ? error.message : String(error));
    }
  });

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  assert(address && typeof address === 'object');
  return {
    origin: `http://127.0.0.1:${address.port}`,
    server,
  };
}

function closeServer(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

function localUrl(url, origin) {
  try {
    return new URL(url).origin === origin;
  } catch {
    return false;
  }
}

async function waitForSettledPage(page) {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForLoadState('networkidle');
  await page.evaluate(
    () =>
      new Promise((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(resolve));
      }),
  );
  await page.waitForTimeout(250);
}

async function runSmoke(page, origin) {
  const issues = [];
  let stage = 'startup';
  const report = (kind, detail) => issues.push(`[${stage}] ${kind}: ${detail}`);

  page.on('console', (message) => {
    const text = message.text();
    if (message.type() === 'error' || hydrationErrorPattern.test(text)) {
      report(`console.${message.type()}`, text);
    }
  });
  page.on('pageerror', (error) => report('pageerror', error.message));
  page.on('requestfailed', (request) => {
    if (localUrl(request.url(), origin)) {
      report(
        'requestfailed',
        `${request.method()} ${request.url()} (${request.failure()?.errorText ?? 'unknown error'})`,
      );
    }
  });
  page.on('response', (response) => {
    if (localUrl(response.url(), origin) && response.status() >= 400) {
      report('response', `${response.status()} ${response.url()}`);
    }
  });

  let assertionError;
  try {
    stage = 'English home';
    await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
    await waitForSettledPage(page);
    await page
      .getByRole('heading', { name: 'Find code problems faster.' })
      .waitFor();
    assert.equal(await page.locator('html').getAttribute('lang'), 'en');

    stage = 'SPA navigation to configuration';
    const initialTimeOrigin = await page.evaluate(() => performance.timeOrigin);
    await page.locator('main a[href="/configuration"]').first().click();
    await page.waitForURL(`${origin}/configuration`);
    await waitForSettledPage(page);
    await page
      .getByRole('heading', { name: 'Configuration', level: 1 })
      .waitFor();
    assert.equal(
      await page.evaluate(() => performance.timeOrigin),
      initialTimeOrigin,
      'The home-to-configuration navigation performed a full document reload instead of an SPA transition.',
    );

    stage = 'Language switch';
    await page
      .locator('a.dumi-default-lang-switch[href="/zh-CN/configuration"]')
      .click();
    await page.waitForURL(`${origin}/zh-CN/configuration`);
    await waitForSettledPage(page);
    assert.equal(await page.locator('html').getAttribute('lang'), 'zh-CN');
    await page.getByRole('heading', { name: '配置', level: 1 }).waitFor();

    stage = 'Chinese home';
    await page.goto(`${origin}/zh-CN/`, { waitUntil: 'networkidle' });
    await waitForSettledPage(page);
    assert.equal(await page.locator('html').getAttribute('lang'), 'zh-CN');
    await page.getByRole('heading', { name: '更快地发现代码问题。' }).waitFor();

    stage = 'Playground';
    await page.locator('main a[href="/playground/"]').first().click();
    await page.waitForURL(`${origin}/playground/`);
    await waitForSettledPage(page);
    await page.getByRole('heading', { name: 'utoo-lint', level: 1 }).waitFor();
    await page
      .locator('.site-nav a[aria-current="page"][href="/playground/"]', {
        hasText: 'Playground',
      })
      .waitFor();
    await page.waitForFunction(
      () =>
        document
          .querySelector('[role="status"]')
          ?.textContent?.includes('Lint complete.'),
      undefined,
      { timeout: 30_000 },
    );

    stage = 'Playground navigation to home';
    await page
      .getByRole('link', { name: 'Back to the utoo-lint homepage' })
      .click();
    await page.waitForURL(`${origin}/`);
    await waitForSettledPage(page);
    await page
      .getByRole('heading', { name: 'Find code problems faster.' })
      .waitFor();

    // Let late worker/resource errors reach the event handlers before evaluating them.
    await page.waitForTimeout(250);
  } catch (error) {
    assertionError = error;
  }

  if (assertionError || issues.length > 0) {
    const details = [
      assertionError instanceof Error ? assertionError.stack : assertionError,
      ...issues,
    ].filter(Boolean);
    throw new Error(`Production browser smoke failed:\n${details.join('\n')}`);
  }
}

async function main() {
  const { origin, server } = await startStaticServer();
  let browser;

  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      colorScheme: 'dark',
      viewport: { height: 900, width: 1440 },
    });
    const page = await context.newPage();
    await runSmoke(page, origin);
    console.log(`Production browser smoke passed at ${origin}`);
  } finally {
    await browser?.close();
    await closeServer(server);
  }
}

await main();
