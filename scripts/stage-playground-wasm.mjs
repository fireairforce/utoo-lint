import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const packagePath = path.join(
  rootDir,
  'npm',
  '@utoo',
  'lint-wasm',
  'utoo-lint.wasm',
);
const releaseUrl =
  'https://github.com/utooland/utoo-lint/releases/download/v0.3.0/utoo-lint.wasm';
const expectedSha256 =
  '535dcb3da3878e2a89ddbc0e8a4a86cd895d2da0e711ec37b6de08807348c1ce';

function sha256(contents) {
  return createHash('sha256').update(contents).digest('hex');
}

async function readCachedRelease() {
  try {
    const contents = await readFile(packagePath);
    return sha256(contents) === expectedSha256 ? contents : undefined;
  } catch (error) {
    if (error?.code === 'ENOENT') return undefined;
    throw error;
  }
}

let contents = await readCachedRelease();
if (!contents) {
  const response = await fetch(releaseUrl, { redirect: 'follow' });
  if (!response.ok) {
    throw new Error(
      `failed to download utoo-lint v0.3.0 WebAssembly: ${response.status} ${response.statusText}`,
    );
  }

  contents = Buffer.from(await response.arrayBuffer());
  const actualSha256 = sha256(contents);
  if (actualSha256 !== expectedSha256) {
    throw new Error(
      `unexpected utoo-lint v0.3.0 WebAssembly SHA-256: ${actualSha256}`,
    );
  }

  await writeFile(packagePath, contents, { mode: 0o644 });
}

console.log(`staged utoo-lint v0.3.0 WebAssembly (${expectedSha256})`);
