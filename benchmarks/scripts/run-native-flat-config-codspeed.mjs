import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { Bench } from "tinybench";
import { withCodSpeed } from "@codspeed/tinybench-plugin";
import { CLIEngine } from "../../npm/utoo-lint/index.js";

const args = parseArgs(process.argv.slice(2));
const fileCount = positiveInt(args.files, 1000, "files");
const time = nonNegativeNumber(args.time, 1000, "time");
const warmupTime = nonNegativeNumber(args["warmup-time"], 500, "warmup-time");
const utooBin = resolve(
  process.env.UTOO_LINT_BIN ?? join("..", "zig-out", "bin", process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint")
);

if (!existsSync(utooBin)) {
  throw new Error(`utoo-lint binary was not found at ${utooBin}. Build utoo-lint first.`);
}

const fixture = createFixture(fileCount);
const engine = new CLIEngine({
  binary: utooBin,
  cwd: fixture.root,
  overrideConfigFile: true,
  overrideConfig: [
    { files: ["packages/*/src/**/*.ts"], rules: { "no-console": "off", "no-debugger": "warn" } },
    { files: ["packages/*/test/**/*.ts"], rules: { "no-console": ["warn", { allow: ["warn"] }], "no-debugger": "off" } },
    { files: ["packages/package-0/test/**/*.ts"], rules: { "no-console": "error" } }
  ]
});
const bench = withCodSpeed(
  new Bench({
    throws: true,
    time,
    warmup: warmupTime > 0,
    warmupTime
  })
);

bench.add(`npm-wrapper/native-flat-config/${fixture.files.length}-files`, () => {
  const report = engine.executeOnFiles(fixture.files);
  if (report.errorCount !== 0 || report.warningCount !== 0 || report.results.length !== fixture.files.length) {
    throw new Error("native flat-config benchmark produced an unexpected lint report");
  }
});

try {
  await bench.run();
  console.table(bench.table());
} finally {
  rmSync(fixture.root, { recursive: true, force: true });
}

function createFixture(count) {
  const root = mkdtempSync(join(tmpdir(), "utoo-lint-flat-config-benchmark-"));
  const files = [];
  for (let index = 0; index < count; index += 1) {
    const scope = index % 2 === 0 ? "src" : "test";
    const directory = join(root, "packages", `package-${Math.floor(index / 2) % 100}`, scope);
    mkdirSync(directory, { recursive: true });
    const file = join(directory, `fixture-${index}.ts`);
    writeFileSync(file, `export const value${index} = ${index};\n`);
    files.push(file);
  }
  return { files, root };
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
