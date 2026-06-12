import { mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { performance } from "node:perf_hooks";

const args = parseArgs(process.argv.slice(2));
const runs = positiveInt(args.runs, 8, "runs");
const warmups = nonNegativeInt(args.warmups, 2, "warmups");
const target = args.target ?? "fixtures/src";
const skipEslint = Boolean(args["skip-eslint"]);

const localBin = join("node_modules", ".bin");
const utooBin = process.env.UTOO_LINT_BIN ?? join("..", "zig-out", "bin", process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint");

const benchmarks = [
  {
    name: "utoo-lint",
    command: utooBin,
    args: [target],
    requiredPath: utooBin
  },
  {
    name: "oxlint",
    command: bin("oxlint"),
    args: [target],
    requiredPath: bin("oxlint")
  },
  {
    name: "biome",
    command: bin("biome"),
    args: ["lint", "--max-diagnostics=0", target],
    requiredPath: bin("biome")
  },
  {
    name: "eslint",
    command: bin("eslint"),
    args: [target],
    requiredPath: bin("eslint"),
    optional: skipEslint
  }
].filter((benchmark) => !benchmark.optional);

for (const benchmark of benchmarks) {
  if (!existsSync(benchmark.requiredPath)) {
    throw new Error(
      `${benchmark.name} binary was not found at ${benchmark.requiredPath}. Run npm install, or build utoo-lint first.`
    );
  }
}

const results = [];

for (const benchmark of benchmarks) {
  for (let i = 0; i < warmups; i += 1) {
    runCommand(benchmark, true);
  }

  const samples = [];
  for (let i = 0; i < runs; i += 1) {
    samples.push(runCommand(benchmark, false));
  }

  results.push({
    name: benchmark.name,
    command: [benchmark.command, ...benchmark.args].join(" "),
    runs,
    warmups,
    samplesMs: samples,
    summary: summarize(samples)
  });
}

const fastest = Math.min(...results.map((result) => result.summary.medianMs));
const printable = results.map((result) => ({
  tool: result.name,
  median: formatMs(result.summary.medianMs),
  mean: formatMs(result.summary.meanMs),
  min: formatMs(result.summary.minMs),
  max: formatMs(result.summary.maxMs),
  relative: `${(result.summary.medianMs / fastest).toFixed(2)}x`
}));

console.table(printable);

await mkdir("results", { recursive: true });
await writeFile(
  "results/latest.json",
  `${JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      node: process.version,
      platform: process.platform,
      arch: process.arch,
      target,
      results
    },
    null,
    2
  )}\n`
);

console.log("Wrote results/latest.json");

function runCommand(benchmark, isWarmup) {
  const started = performance.now();
  const result = spawnSync(benchmark.command, benchmark.args, {
    cwd: process.cwd(),
    env: {
      ...process.env,
      CI: "1",
      NO_COLOR: "1"
    },
    encoding: "utf8",
    stdio: isWarmup ? "ignore" : "pipe"
  });
  const elapsed = performance.now() - started;

  if (result.error || result.status !== 0) {
    const detail = [
      result.error?.message,
      result.stdout?.trim(),
      result.stderr?.trim()
    ]
      .filter(Boolean)
      .join("\n");
    throw new Error(`${benchmark.name} failed with status ${result.status ?? "unknown"}:\n${detail}`);
  }

  return Number(elapsed.toFixed(3));
}

function summarize(samples) {
  const sorted = [...samples].sort((a, b) => a - b);
  const sum = samples.reduce((total, value) => total + value, 0);
  const mean = sum / samples.length;
  const variance = samples.reduce((total, value) => total + (value - mean) ** 2, 0) / samples.length;

  return {
    minMs: sorted[0],
    maxMs: sorted[sorted.length - 1],
    meanMs: Number(mean.toFixed(3)),
    medianMs: median(sorted),
    standardDeviationMs: Number(Math.sqrt(variance).toFixed(3))
  };
}

function median(sorted) {
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[middle];
  }
  return Number(((sorted[middle - 1] + sorted[middle]) / 2).toFixed(3));
}

function formatMs(value) {
  return `${value.toFixed(1)} ms`;
}

function bin(name) {
  const suffix = process.platform === "win32" ? ".cmd" : "";
  return join(localBin, `${name}${suffix}`);
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

function positiveInt(value, fallback, name) {
  if (value === undefined) {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`--${name} must be a positive integer`);
  }
  return parsed;
}

function nonNegativeInt(value, fallback, name) {
  if (value === undefined) {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`--${name} must be a non-negative integer`);
  }
  return parsed;
}
