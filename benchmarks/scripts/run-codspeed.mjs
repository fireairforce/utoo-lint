import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { Bench } from "tinybench";
import { withCodSpeed } from "@codspeed/tinybench-plugin";
import { findConfigPath } from "../../npm/utoo-lint/lib/config-loader.js";
import { benchmarkRuleNames, utooRuleArgs } from "./shared-rules.mjs";

const args = parseArgs(process.argv.slice(2));
const configOnly = Boolean(args["config-only"]);
const target = args.target ?? "fixtures/codspeed";
const time = nonNegativeNumber(args.time, 1000, "time");
const warmupTime = nonNegativeNumber(args["warmup-time"], 500, "warmup-time");
const utooBin = resolve(process.env.UTOO_LINT_BIN ?? join("..", "zig-out", "bin", process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint"));

if (!configOnly && !existsSync(utooBin)) {
  throw new Error(`utoo-lint binary was not found at ${utooBin}. Build utoo-lint first.`);
}

if (!configOnly && !existsSync(target)) {
  throw new Error(`benchmark target was not found at ${target}. Run npm run generate first.`);
}

const bench = withCodSpeed(
  new Bench({
    throws: true,
    time,
    warmup: warmupTime > 0,
    warmupTime
  })
);
if (!configOnly) {
  bench.add(`utoo-lint/${target}`, () => {
    runUtooLint(target);
  });
  console.log(`Rules: ${benchmarkRuleNames().join(", ")}`);
}

const configFixture = createConfigDiscoveryFixture();
bench.add("npm-wrapper/config-discovery/uncached-1000-inputs", () => {
  discoverConfigs(configFixture, false);
});
bench.add("npm-wrapper/config-discovery/cached-1000-inputs", () => {
  discoverConfigs(configFixture, true);
});

try {
  await bench.run();
  console.table(bench.table());
} finally {
  rmSync(configFixture.root, { recursive: true, force: true });
}

function runUtooLint(targetPath) {
  const result = spawnSync(utooBin, [...utooRuleArgs(), targetPath], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      CI: "1",
      NO_COLOR: "1"
    },
    encoding: "utf8",
    stdio: "pipe"
  });

  if (result.error || result.status !== 0) {
    const detail = [
      result.error?.message,
      result.stdout?.trim(),
      result.stderr?.trim()
    ]
      .filter(Boolean)
      .join("\n");
    throw new Error(`utoo-lint failed with status ${result.status ?? "unknown"}:\n${detail}`);
  }
}

function createConfigDiscoveryFixture() {
  const root = mkdtempSync(join(tmpdir(), "utoo-lint-config-benchmark-"));
  const configPath = join(root, "utlint.config.json");
  writeFileSync(configPath, "{}\n");
  const directories = [];

  for (let packageIndex = 0; packageIndex < 100; packageIndex += 1) {
    const directory = join(root, "packages", `package-${packageIndex}`, "src", "features");
    mkdirSync(directory, { recursive: true });
    for (let fileIndex = 0; fileIndex < 10; fileIndex += 1) {
      directories.push(directory);
    }
  }

  return { configPath, directories, root };
}

function discoverConfigs(fixture, cached) {
  const cache = cached ? new Map() : undefined;
  for (const directory of fixture.directories) {
    if (findConfigPath(directory, cache) !== fixture.configPath) {
      throw new Error(`config discovery failed for ${directory}`);
    }
  }
}

function parseArgs(argv) {
  const result = {};
  for (const arg of argv) {
    if (!arg.startsWith("--")) {
      throw new Error(`Unknown positional argument: ${arg}`);
    }

    const [rawKey, rawValue] = arg.slice(2).split("=", 2);
    result[rawKey] = rawValue ?? "true";
  }
  return result;
}

function nonNegativeNumber(value, fallback, name) {
  if (value === undefined) {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`--${name} must be a non-negative number`);
  }
  return parsed;
}
