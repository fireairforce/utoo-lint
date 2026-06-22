const { chmodSync, existsSync, statSync } = require("node:fs");
const { join } = require("node:path");

const here = __dirname;

const packages = {
  "darwin-arm64": "@utoo/lint-darwin-arm64",
  "darwin-x64": "@utoo/lint-darwin-x64",
  "linux-arm64": "@utoo/lint-linux-arm64",
  "linux-x64": "@utoo/lint-linux-x64",
  "win32-x64": "@utoo/lint-win32-x64"
};

function platformPackageName(platform = process.platform, arch = process.arch) {
  return packages[`${platform}-${arch}`] ?? null;
}

function binaryName(platform) {
  return platform === "win32" ? "utoo-lint.exe" : "utoo-lint";
}

function resolveBinary(options = {}) {
  const env = options.env ?? process.env;
  const platform = options.platform ?? process.platform;
  const arch = options.arch ?? process.arch;

  if (env.UTOO_LINT_BIN) {
    if (existsSync(env.UTOO_LINT_BIN)) {
      return ensureExecutable(env.UTOO_LINT_BIN, platform);
    }
    throw new Error(`utoo-lint: UTOO_LINT_BIN does not exist: ${env.UTOO_LINT_BIN}`);
  }

  const packageName = platformPackageName(platform, arch);
  if (!packageName) {
    throw new Error(`utoo-lint: unsupported platform ${platform}-${arch}`);
  }
  const executable = binaryName(platform);

  const candidates = [
    () => require.resolve(`${packageName}/bin/${executable}`),
    () => join(here, "..", "..", packageName, "bin", executable),
    () => join(here, "..", "..", "..", "zig-out", "bin", executable)
  ];

  for (const candidate of candidates) {
    try {
      const resolved = candidate();
      if (existsSync(resolved)) {
        return ensureExecutable(resolved, platform);
      }
    } catch {}
  }

  throw new Error(
    `utoo-lint: missing native package ${packageName}. ` +
      "Run `./scripts/package-npm.sh` from the repository root, or install the matching optional dependency."
  );
}

function ensureExecutable(path, platform) {
  if (platform === "win32") {
    return path;
  }
  try {
    const mode = statSync(path).mode;
    if ((mode & 0o111) === 0) {
      chmodSync(path, mode | 0o755);
    }
  } catch {
    // Let spawn surface the actual filesystem error if chmod is not permitted.
  }
  return path;
}

module.exports = {
  platformPackageName,
  resolveBinary
};
