import { copyFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

await copyFile(
  path.join(appDir, 'public', '_headers'),
  path.join(appDir, 'dist', 'client', '_headers'),
);
