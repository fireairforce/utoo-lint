import { cp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);
const playgroundDir = path.join(
  repoDir,
  'apps',
  'playground',
  'dist',
  'client',
);
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

function findClosingDiv(html, openingTagStart, label) {
  const tokenPattern = /<div\b[^>]*>|<\/div\s*>/gi;
  tokenPattern.lastIndex = openingTagStart;
  let depth = 0;

  for (
    let match = tokenPattern.exec(html);
    match;
    match = tokenPattern.exec(html)
  ) {
    if (/^<\/div/i.test(match[0])) depth -= 1;
    else depth += 1;

    if (depth === 0) {
      return { end: tokenPattern.lastIndex, start: match.index };
    }
  }

  throw new Error(`unable to close streamed segment in ${label}`);
}

function findSuspenseBoundaryEnd(html, openingCommentIndex, label) {
  const boundaryPattern = /<!--(?:\$\??|\$!|\/\$)-->/g;
  boundaryPattern.lastIndex = openingCommentIndex;
  let depth = 0;

  for (
    let match = boundaryPattern.exec(html);
    match;
    match = boundaryPattern.exec(html)
  ) {
    if (match[0] === '<!--/$-->') depth -= 1;
    else depth += 1;

    if (depth === 0) return boundaryPattern.lastIndex;
  }

  throw new Error(`unable to close Suspense boundary in ${label}`);
}

function removeScriptContaining(html, marker, label) {
  const markerIndex = html.indexOf(marker);
  if (markerIndex === -1) {
    throw new Error(`missing streamed segment resolver in ${label}: ${marker}`);
  }

  const scriptStart = html.lastIndexOf('<script', markerIndex);
  const scriptEnd = html.indexOf('</script>', markerIndex);
  if (scriptStart === -1 || scriptEnd === -1) {
    throw new Error(`unable to remove streamed segment resolver in ${label}`);
  }

  return `${html.slice(0, scriptStart)}${html.slice(scriptEnd + 9)}`;
}

function collapseStaticSuspenseSegments(html, label) {
  const segmentIds = [
    ...html.matchAll(
      /<div\b(?=[^>]*\bhidden(?:\s|=|>))(?=[^>]*\bid="S:([^"]+)")[^>]*>/gi,
    ),
  ].map((match) => match[1]);

  for (const segmentId of segmentIds) {
    const segmentPattern = new RegExp(
      `<div\\b(?=[^>]*\\bhidden(?:\\s|=|>))(?=[^>]*\\bid="S:${segmentId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}")[^>]*>`,
      'i',
    );
    const segmentMatch = segmentPattern.exec(html);
    if (!segmentMatch) {
      throw new Error(`missing streamed segment S:${segmentId} in ${label}`);
    }

    const segmentStart = segmentMatch.index;
    const segmentContentStart = segmentStart + segmentMatch[0].length;
    const segmentEnd = findClosingDiv(html, segmentStart, label);
    const segmentContent = html.slice(segmentContentStart, segmentEnd.start);
    html = `${html.slice(0, segmentStart)}${html.slice(segmentEnd.end)}`;

    const template = `<template id="B:${segmentId}"></template>`;
    const templateIndex = html.indexOf(template);
    if (templateIndex === -1) {
      throw new Error(`missing Suspense template B:${segmentId} in ${label}`);
    }

    const boundaryStart = html.lastIndexOf('<!--$?-->', templateIndex);
    if (boundaryStart === -1) {
      throw new Error(`missing Suspense boundary B:${segmentId} in ${label}`);
    }
    const boundaryEnd = findSuspenseBoundaryEnd(html, boundaryStart, label);
    html = `${html.slice(0, boundaryStart)}<!--$-->${segmentContent}<!--/$-->${html.slice(boundaryEnd)}`;
    html = removeScriptContaining(
      html,
      `$RC("B:${segmentId}","S:${segmentId}")`,
      label,
    );
  }

  return { collapsedSegments: segmentIds.length, html };
}

async function normalizeStaticDocuments(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  let collapsedSegments = 0;
  let updatedCount = 0;
  let removedNullBytes = 0;

  for (const entry of entries) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      const result = await normalizeStaticDocuments(absolutePath);
      collapsedSegments += result.collapsedSegments;
      updatedCount += result.updatedCount;
      removedNullBytes += result.removedNullBytes;
      continue;
    }
    if (!entry.isFile() || path.extname(entry.name) !== '.html') continue;

    const originalHtml = await readFile(absolutePath, 'utf8');
    removedNullBytes += originalHtml.match(/\0/g)?.length ?? 0;
    let html = originalHtml.replaceAll('\0', '');
    const collapsed = collapseStaticSuspenseSegments(
      html,
      path.relative(repoDir, absolutePath),
    );
    collapsedSegments += collapsed.collapsedSegments;
    html = collapsed.html;
    const closingHtmlIndex = html.search(/<\/html\s*>/i);

    if (closingHtmlIndex === -1) {
      throw new Error(
        `unable to find document end: ${path.relative(repoDir, absolutePath)}`,
      );
    }

    const closingHtml = html.slice(closingHtmlIndex).match(/^<\/html\s*>/i)[0];
    const trailingMarkup = html
      .slice(closingHtmlIndex + closingHtml.length)
      .trim();
    if (trailingMarkup) {
      if (!/<\/body\s*>/i.test(html)) {
        throw new Error(
          `unable to find document body: ${path.relative(repoDir, absolutePath)}`,
        );
      }
      html = html
        .slice(0, closingHtmlIndex + closingHtml.length)
        .replace(/<\/body\s*>/i, `${trailingMarkup}</body>`);
    }

    if (html !== originalHtml) {
      await writeFile(absolutePath, html);
      updatedCount += 1;
    }
  }

  return { collapsedSegments, removedNullBytes, updatedCount };
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
const normalizedDocuments = await normalizeStaticDocuments(siteDir);
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
  `assembled unified site (${await countFiles(siteDir)} files, ${localizedDocumentCount} Chinese documents, ${normalizedDocuments.collapsedSegments} collapsed Suspense segments, ${normalizedDocuments.updatedCount} normalized documents, ${normalizedDocuments.removedNullBytes} removed null bytes, Playground at /playground/)`,
);
