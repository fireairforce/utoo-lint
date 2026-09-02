export interface LintVersionDefinition {
  id: string;
  label: string;
  wasmUrl: string;
}

export interface LintVersionCatalog {
  latest: string;
  versions: LintVersionDefinition[];
}

interface ManifestVersion {
  id: string;
  label: string;
  file: string;
  sha256: string;
}

interface VersionManifest {
  latest: string;
  versions: ManifestVersion[];
}

const VERSION_PATTERN = /^\d+\.\d+\.\d+$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;

function isManifestVersion(value: unknown): value is ManifestVersion {
  if (!value || typeof value !== 'object') return false;
  const version = value as Partial<ManifestVersion>;
  return (
    typeof version.id === 'string' &&
    VERSION_PATTERN.test(version.id) &&
    version.label === `v${version.id}` &&
    version.file === `utoo-lint-v${version.id}.wasm` &&
    typeof version.sha256 === 'string' &&
    SHA256_PATTERN.test(version.sha256)
  );
}

export function lintVersionManifestUrl(pageUrl: string): string {
  return new URL('versions/manifest.json', pageUrl).href;
}

export function parseLintVersionCatalog(
  value: unknown,
  manifestUrl: string,
): LintVersionCatalog {
  if (!value || typeof value !== 'object') {
    throw new Error('The Playground version manifest is invalid.');
  }

  const manifest = value as Partial<VersionManifest>;
  if (
    typeof manifest.latest !== 'string' ||
    !VERSION_PATTERN.test(manifest.latest) ||
    !Array.isArray(manifest.versions) ||
    manifest.versions.length === 0 ||
    !manifest.versions.every(isManifestVersion)
  ) {
    throw new Error('The Playground version manifest is invalid.');
  }

  const ids = new Set(manifest.versions.map(({ id }) => id));
  if (ids.size !== manifest.versions.length || !ids.has(manifest.latest)) {
    throw new Error('The Playground version manifest is inconsistent.');
  }

  return {
    latest: manifest.latest,
    versions: manifest.versions.map(({ id, label, file }) => ({
      id,
      label,
      wasmUrl: new URL(file, manifestUrl).href,
    })),
  };
}

export async function loadLintVersionCatalog(
  manifestUrl: string,
): Promise<LintVersionCatalog> {
  const response = await fetch(manifestUrl, { credentials: 'same-origin' });
  if (!response.ok) {
    throw new Error(
      `Unable to load Playground versions (${response.status} ${response.statusText}).`,
    );
  }
  return parseLintVersionCatalog(await response.json(), manifestUrl);
}

export function initialLintVersion(
  catalog: LintVersionCatalog,
  currentUrl: string,
): string {
  const requested = new URL(currentUrl).searchParams.get('version');
  return catalog.versions.some(({ id }) => id === requested)
    ? requested!
    : catalog.latest;
}

export function lintVersionUrl(
  currentUrl: string,
  version: string,
  latest: string,
): string {
  const url = new URL(currentUrl);
  if (version === latest) url.searchParams.delete('version');
  else url.searchParams.set('version', version);
  return url.href;
}
