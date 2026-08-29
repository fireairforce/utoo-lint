import { copyFile, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const clientDir = path.join(appDir, 'dist', 'client');
const indexFile = path.join(clientDir, 'index.html');
const playgroundBase = '/playground/';

await copyFile(
  path.join(appDir, 'public', '_headers'),
  path.join(clientDir, '_headers'),
);

const indexHtml = await readFile(indexFile, 'utf8');
const subpathHtml = indexHtml.replace(
  /\b(href|src)="\/(?!\/)/g,
  `$1="${playgroundBase}`,
);

if (subpathHtml === indexHtml) {
  throw new Error('expected root-relative Playground assets in index.html');
}

await writeFile(indexFile, subpathHtml);
