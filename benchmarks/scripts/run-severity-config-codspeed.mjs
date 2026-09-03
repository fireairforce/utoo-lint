import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { Bench } from "tinybench";
import { withCodSpeed } from "@codspeed/tinybench-plugin";
import { CLIEngine, Linter } from "../../npm/utoo-lint/index.js";
import { benchmarkRuleNames } from "./shared-rules.mjs";

const args = parseArgs(process.argv.slice(2));
const fileCount = positiveInt(args.files, 1000, "files");
const runs = positiveInt(args.runs, 8, "runs");
const warmups = nonNegativeInt(args.warmups, 2, "warmups");
const utooBin = resolve(
  process.env.UTOO_LINT_BIN ?? join("..", "zig-out", "bin", process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint")
);

if (!existsSync(utooBin)) {
  throw new Error(`utoo-lint binary was not found at ${utooBin}. Build utoo-lint first.`);
}

const fixture = createFixture(fileCount);
const severityOnly = createEngine(fixture);
const bench = withCodSpeed(new Bench({
  iterations: runs,
  time: 0,
  throws: true,
  warmup: warmups > 0,
  warmupIterations: warmups,
  warmupTime: 0
}));

bench.add(`npm-wrapper/umi-severity-config/${fileCount}-files`, () => {
  runEngine(severityOnly, fixture.files);
});

try {
  await bench.run();
  console.table(bench.table());
} finally {
  rmSync(fixture.root, { recursive: true, force: true });
}

function createFixture(count) {
  const root = mkdtempSync(join(tmpdir(), "utoo-lint-severity-benchmark-"));
  const files = [];
  for (let index = 0; index < count; index += 1) {
    const directory = join(root, "packages", `package-${index % 100}`, "src");
    mkdirSync(directory, { recursive: true });
    const file = join(directory, `fixture-${index}.ts`);
    writeFileSync(file, `export const value${index} = ${index};\n`);
    files.push(file);
  }
  return { files, root };
}

function createEngine(fixture) {
  const enabled = new Set(benchmarkRuleNames());
  const enabledSeverities = ["warn", 1, true, ["error"]];
  const disabledSeverities = ["off", 0, false, ["off"]];
  const availableRules = [...new Linter().getRules().keys()];
  const configuredRules = new Set([...availableRules.slice(0, 64), ...enabled]);
  const rules = Object.fromEntries(
    availableRules
      .filter((rule) => configuredRules.has(rule))
      .map((rule, index) => [
        rule,
        enabled.has(rule)
          ? enabledSeverities[index % enabledSeverities.length]
          : disabledSeverities[index % disabledSeverities.length]
      ])
  );
  return new CLIEngine({
    binary: utooBin,
    cwd: fixture.root,
    overrideConfigFile: true,
    overrideConfig: [{ files: ["packages/**/*.ts"], rules }]
  });
}

function runEngine(engine, files) {
  const report = engine.executeOnFiles(files);
  if (report.errorCount !== 0 || report.warningCount !== 0 || report.results.length !== files.length) {
    throw new Error("severity config benchmark produced an unexpected lint report");
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

function positiveInt(value, fallback, name) {
  const parsed = value === undefined ? fallback : Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`--${name} must be a positive integer`);
  }
  return parsed;
}

function nonNegativeInt(value, fallback, name) {
  const parsed = value === undefined ? fallback : Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`--${name} must be a non-negative integer`);
  }
  return parsed;
}
