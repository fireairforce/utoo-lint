import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';

const rootDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);
const packagePath = path.join(
  rootDir,
  'npm',
  '@utoo',
  'lint-wasm',
  'utoo-lint.wasm',
);
const versionsDir = path.join(
  rootDir,
  'apps',
  'playground',
  'public',
  'versions',
);
const releasesUrl =
  'https://api.github.com/repos/utooland/utoo-lint/releases?per_page=100';
const releaseAssetName = 'utoo-lint.wasm';
const compressedAssetName = `${releaseAssetName}.gz`;
const maxVersions = 10;

function sha256(contents) {
  return createHash('sha256').update(contents).digest('hex');
}

function githubHeaders() {
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
  return {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'utoo-lint-playground-build',
    'X-GitHub-Api-Version': '2022-11-28',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

function githubAssetHeaders() {
  return {
    ...githubHeaders(),
    Accept: 'application/octet-stream',
  };
}

async function fetchChecked(url, options) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    let response;
    try {
      response = await fetch(url, { redirect: 'follow', ...options });
    } catch (error) {
      lastError = error;
    }

    if (response?.ok) return response;
    if (response) {
      lastError = new Error(
        `failed to download ${url}: ${response.status} ${response.statusText}`,
      );
      if (response.status !== 429 && response.status < 500) throw lastError;
    }

    if (attempt < 3) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 1_000));
    }
  }
  throw lastError;
}

async function expectedDigest(release, asset) {
  const digest = asset.digest?.match(/^sha256:([a-f0-9]{64})$/i)?.[1];
  if (digest) return digest.toLowerCase();

  const checksumAsset = release.assets.find(
    (candidate) => candidate.name === `${releaseAssetName}.sha256`,
  );
  if (!checksumAsset) {
    throw new Error(
      `${release.tag_name} is missing a SHA-256 digest for ${releaseAssetName}`,
    );
  }

  const checksum = await (
    await fetchChecked(checksumAsset.url, {
      headers: githubAssetHeaders(),
    })
  ).text();
  const match = checksum.match(/\b([a-f0-9]{64})\b/i);
  if (!match) {
    throw new Error(`invalid ${release.tag_name} ${releaseAssetName}.sha256`);
  }
  return match[1].toLowerCase();
}

function isStableVersionTag(tagName) {
  return /^v\d+\.\d+\.\d+$/.test(tagName);
}

function compareStableVersionsDescending(left, right) {
  const leftParts = left.tag_name.slice(1).split('.').map(Number);
  const rightParts = right.tag_name.slice(1).split('.').map(Number);
  for (let index = 0; index < leftParts.length; index += 1) {
    if (leftParts[index] !== rightParts[index]) {
      return rightParts[index] - leftParts[index];
    }
  }
  return 0;
}

async function discoverVersions() {
  const response = await fetchChecked(releasesUrl, {
    headers: githubHeaders(),
  });
  const releases = await response.json();
  if (!Array.isArray(releases)) {
    throw new Error('GitHub releases response was not an array');
  }

  const candidates = releases
    .filter(
      (release) =>
        !release.draft &&
        !release.prerelease &&
        isStableVersionTag(release.tag_name) &&
        release.assets?.some((asset) => asset.name === releaseAssetName),
    )
    .sort(compareStableVersionsDescending)
    .slice(0, maxVersions);

  if (candidates.length === 0) {
    throw new Error(`no stable GitHub release contains ${releaseAssetName}`);
  }

  return Promise.all(
    candidates.map(async (release) => {
      const asset = release.assets.find(
        (candidate) => candidate.name === releaseAssetName,
      );
      const compressedAsset = release.assets.find(
        (candidate) => candidate.name === compressedAssetName,
      );
      return {
        id: release.tag_name.slice(1),
        label: release.tag_name,
        publishedAt: release.published_at,
        asset,
        downloadAsset: compressedAsset ?? asset,
        compressed: Boolean(compressedAsset),
        sha256: await expectedDigest(release, asset),
      };
    }),
  );
}

async function discoverCachedVersions() {
  const manifest = JSON.parse(
    await readFile(path.join(versionsDir, 'manifest.json'), 'utf8'),
  );
  if (
    !Array.isArray(manifest.versions) ||
    manifest.versions.length === 0 ||
    manifest.versions[0]?.id !== manifest.latest ||
    !manifest.versions.every(
      (version) =>
        typeof version.id === 'string' &&
        isStableVersionTag(`v${version.id}`) &&
        version.label === `v${version.id}` &&
        version.file === `utoo-lint-v${version.id}.wasm` &&
        /^[a-f0-9]{64}$/.test(version.sha256),
    )
  ) {
    throw new Error('cached Playground version manifest is invalid');
  }
  return manifest.versions.map((version) => ({
    ...version,
    cachedOnly: true,
  }));
}

async function discoverVersionsWithLocalFallback() {
  try {
    return await discoverVersions();
  } catch (error) {
    if (process.env.CI) throw error;
    try {
      const cached = await discoverCachedVersions();
      console.warn(
        `unable to refresh GitHub releases; using ${cached.length} cached Playground versions`,
      );
      return cached;
    } catch {
      throw error;
    }
  }
}

async function readCachedAsset(file, expectedSha256) {
  try {
    const contents = await readFile(file);
    return sha256(contents) === expectedSha256 ? contents : undefined;
  } catch (error) {
    if (error?.code === 'ENOENT') return undefined;
    throw error;
  }
}

async function stageVersion(version) {
  const file = `utoo-lint-v${version.id}.wasm`;
  const target = path.join(versionsDir, file);
  let contents = await readCachedAsset(target, version.sha256);

  if (!contents) {
    if (version.cachedOnly) {
      throw new Error(
        `cached ${version.label} WebAssembly is missing or invalid`,
      );
    }
    console.log(
      `downloading utoo-lint ${version.label} WebAssembly${version.compressed ? ' (gzip)' : ''}`,
    );
    const downloaded = Buffer.from(
      await (
        await fetchChecked(version.downloadAsset.url, {
          headers: githubAssetHeaders(),
        })
      ).arrayBuffer(),
    );
    contents = version.compressed ? gunzipSync(downloaded) : downloaded;
    const actualSha256 = sha256(contents);
    if (actualSha256 !== version.sha256) {
      throw new Error(
        `unexpected ${version.label} WebAssembly SHA-256: ${actualSha256}`,
      );
    }
    if (!contents.subarray(0, 4).equals(Buffer.from([0, 97, 115, 109]))) {
      throw new Error(`invalid ${version.label} WebAssembly module`);
    }
    await writeFile(target, contents, { mode: 0o644 });
  }

  return {
    id: version.id,
    label: version.label,
    file,
    sha256: version.sha256,
    publishedAt: version.publishedAt,
    contents,
  };
}

await mkdir(versionsDir, { recursive: true });
const versions = await discoverVersionsWithLocalFallback();
const expectedFiles = new Set([
  'manifest.json',
  ...versions.map(({ id }) => `utoo-lint-v${id}.wasm`),
]);
for (const entry of await readdir(versionsDir, { withFileTypes: true })) {
  if (entry.isFile() && !expectedFiles.has(entry.name)) {
    await rm(path.join(versionsDir, entry.name));
  }
}

const stagedVersions = [];
for (const version of versions) {
  stagedVersions.push(await stageVersion(version));
}

const latest = stagedVersions[0];
await writeFile(packagePath, latest.contents, { mode: 0o644 });
await writeFile(
  path.join(versionsDir, 'manifest.json'),
  `${JSON.stringify(
    {
      latest: latest.id,
      versions: stagedVersions.map(
        ({ contents: _contents, ...version }) => version,
      ),
    },
    null,
    2,
  )}\n`,
);

console.log(
  `staged ${stagedVersions.length} utoo-lint WebAssembly versions; latest is ${latest.label}`,
);
