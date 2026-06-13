import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { Bench } from "tinybench";
import { withCodSpeed } from "@codspeed/tinybench-plugin";
import { benchmarkRuleNames, utooRuleArgs } from "./shared-rules.mjs";

const args = parseArgs(process.argv.slice(2));
const target = args.target ?? "fixtures/codspeed";
const time = nonNegativeNumber(args.time, 1000, "time");
const warmupTime = nonNegativeNumber(args["warmup-time"], 500, "warmup-time");
const utooBin = process.env.UTOO_LINT_BIN ?? join("..", "zig-out", "bin", process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint");

if (!existsSync(utooBin)) {
  throw new Error(`utoo-lint binary was not found at ${utooBin}. Build utoo-lint first.`);
}

if (!existsSync(target)) {
  throw new Error(`benchmark target was not found at ${target}. Run npm run generate first.`);
}

const bench = withCodSpeed(
  new Bench({
    time,
    warmup: warmupTime > 0,
    warmupTime
  })
);

bench.add(`utoo-lint/${target}`, () => {
  runUtooLint(target);
});

console.log(`Rules: ${benchmarkRuleNames().join(", ")}`);

await bench.run();
console.table(bench.table());

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
