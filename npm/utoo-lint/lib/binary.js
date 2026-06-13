import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const packages = {
  "darwin-arm64": "@utoo/lint-darwin-arm64"
};

export function platformPackageName(platform = process.platform, arch = process.arch) {
  return packages[`${platform}-${arch}`] ?? null;
}

export function resolveBinary(options = {}) {
  const env = options.env ?? process.env;
  const platform = options.platform ?? process.platform;
  const arch = options.arch ?? process.arch;

  if (env.UTOO_LINT_BIN) {
    if (existsSync(env.UTOO_LINT_BIN)) {
      return env.UTOO_LINT_BIN;
    }
    throw new Error(`utoo-lint: UTOO_LINT_BIN does not exist: ${env.UTOO_LINT_BIN}`);
  }

  const packageName = platformPackageName(platform, arch);
  if (!packageName) {
    throw new Error(`utoo-lint: unsupported platform ${platform}-${arch}`);
  }

  const candidates = [
    () => require.resolve(`${packageName}/bin/utoo-lint`),
    () => join(here, "..", "..", packageName, "bin", "utoo-lint"),
    () => join(here, "..", "..", "..", "zig-out", "bin", "utoo-lint")
  ];

  for (const candidate of candidates) {
    try {
      const resolved = candidate();
      if (existsSync(resolved)) {
        return resolved;
      }
    } catch {}
  }

  throw new Error(
    `utoo-lint: missing native package ${packageName}. ` +
      "Run `./scripts/package-npm.sh` from the repository root, or install the matching optional dependency."
  );
}
