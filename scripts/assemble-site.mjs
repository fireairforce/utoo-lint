import { cp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const playgroundDir = path.join(repoDir, 'apps', 'playground', 'dist', 'client');
const siteDir = path.join(repoDir, 'dist', 'site');
const destinationDir = path.join(siteDir, 'playground');
const rootControlFiles = new Set(['_headers', '_redirects']);
const playgroundUrl = 'https://utlint.umijs.org/playground/';

async function assertDirectory(directory, label) {
  const entry = await stat(directory).catch(() => undefined);
  if (!entry?.isDirectory()) {
    throw new Error(`missing ${label}: ${path.relative(repoDir, directory)}`);
  }
}

async function countFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  let count = 0;

  for (const entry of entries) {
    count += entry.isDirectory()
      ? await countFiles(path.join(directory, entry.name))
      : Number(entry.isFile());
  }

  return count;
}

async function setDocumentLanguage(directory, language) {
  const entries = await readdir(directory, { withFileTypes: true });
  let updatedCount = 0;

  for (const entry of entries) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      updatedCount += await setDocumentLanguage(absolutePath, language);
      continue;
    }
    if (!entry.isFile() || path.extname(entry.name) !== '.html') continue;

    const html = await readFile(absolutePath, 'utf8');
    if (!/<html\b[^>]*>/i.test(html)) {
      throw new Error(
        `unable to find document root: ${path.relative(repoDir, absolutePath)}`,
      );
    }
    const localizedHtml = html.replace(/<html\b[^>]*>/i, (openingTag) =>
      /\blang\s*=/i.test(openingTag)
        ? openingTag.replace(
            /\blang\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/i,
            `lang="${language}"`,
          )
        : openingTag.replace('<html', `<html lang="${language}"`),
    );
    if (localizedHtml !== html) await writeFile(absolutePath, localizedHtml);
    updatedCount += 1;
  }

  return updatedCount;
}

await assertDirectory(siteDir, 'dumi output');
await assertDirectory(playgroundDir, 'Playground output');
const localizedDocumentCount = await setDocumentLanguage(
  path.join(siteDir, 'zh-CN'),
  'zh-CN',
);
await rm(destinationDir, { force: true, recursive: true });
await cp(playgroundDir, destinationDir, {
  recursive: true,
  filter(source) {
    const relative = path.relative(playgroundDir, source);
    return !rootControlFiles.has(relative);
  },
});

const sitemapFile = path.join(siteDir, 'sitemap.xml');
const sitemap = await readFile(sitemapFile, 'utf8');
if (!sitemap.includes(playgroundUrl)) {
  await writeFile(
    sitemapFile,
    sitemap.replace(
      '</urlset>',
      `  <url><loc>${playgroundUrl}</loc></url>\n</urlset>`,
    ),
  );
}

console.log(
  `assembled unified site (${await countFiles(siteDir)} files, ${localizedDocumentCount} Chinese documents, Playground at /playground/)`,
);
