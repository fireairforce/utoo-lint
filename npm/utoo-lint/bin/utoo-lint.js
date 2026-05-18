#!/usr/bin/env node
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const packages = {
  "darwin-arm64": "utoo-lint-darwin-arm64"
};

const platformKey = `${process.platform}-${process.arch}`;
const packageName = packages[platformKey];

if (!packageName) {
  console.error(`utoo-lint: unsupported platform ${platformKey}`);
  process.exit(1);
}

const candidates = [
  () => require.resolve(`${packageName}/bin/utoo-lint`),
  () => join(here, "..", "..", packageName, "bin", "utoo-lint"),
  () => join(here, "..", "..", "..", "zig-out", "bin", "utoo-lint")
];

let binary = null;
for (const candidate of candidates) {
  try {
    const resolved = candidate();
    if (existsSync(resolved)) {
      binary = resolved;
      break;
    }
  } catch {}
}

if (!binary) {
  console.error(`utoo-lint: missing native package ${packageName}`);
  console.error("Run `./scripts/package-npm.sh` from the repository root, or install the matching optional dependency.");
  process.exit(1);
}

const result = spawnSync(binary, process.argv.slice(2), { stdio: "inherit" });

if (result.error) {
  console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
