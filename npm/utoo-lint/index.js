import { spawnSync } from "node:child_process";

import { resolveBinary } from "./lib/binary.js";

export { platformPackageName, resolveBinary } from "./lib/binary.js";

export function run(args = [], options = {}) {
  const cliArgs = normalizeStringArray(args, "args");
  const env = options.env ? { ...process.env, ...options.env } : process.env;
  const binary = options.binary ?? resolveBinary({ env });

  return spawnSync(binary, cliArgs, {
    cwd: options.cwd,
    env,
    encoding: options.encoding ?? "utf8",
    stdio: options.stdio
  });
}

export function lintFiles(paths = ["."], options = {}) {
  const cliArgs = buildLintArgs(paths, options);
  const result = run(cliArgs, { ...options, stdio: undefined, encoding: "utf8" });

  if (result.error) {
    throw result.error;
  }

  const status = result.status ?? 1;
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";

  if (status !== 0 && status !== 1) {
    throw new Error(stderr.trim() || `utoo-lint exited with status ${status}`);
  }

  let report;
  try {
    report = JSON.parse(stdout);
  } catch (error) {
    throw new Error(`utoo-lint returned invalid JSON: ${error.message}`);
  }

  report.exitCode = status;
  if (stderr) {
    Object.defineProperty(report, "stderr", {
      value: stderr,
      enumerable: false
    });
  }

  return report;
}

function buildLintArgs(paths, options) {
  const cliArgs = [];

  if (options.config) {
    cliArgs.push(`--config=${options.config}`);
  }
  if (options.noConfig) {
    cliArgs.push("--no-config");
  }
  if (options.rules) {
    const rules = Array.isArray(options.rules) ? options.rules.join(",") : options.rules;
    cliArgs.push(`--rules=${rules}`);
  }
  if (options.threads != null) {
    cliArgs.push(`--threads=${options.threads}`);
  }

  cliArgs.push("--format=json");

  if (options.extraArgs) {
    cliArgs.push(...normalizeStringArray(options.extraArgs, "extraArgs"));
  }

  cliArgs.push(...normalizeStringArray(Array.isArray(paths) ? paths : [paths], "paths"));
  return cliArgs;
}

function normalizeStringArray(values, name) {
  if (!Array.isArray(values)) {
    throw new TypeError(`${name} must be an array of strings`);
  }
  for (const value of values) {
    if (typeof value !== "string") {
      throw new TypeError(`${name} must be an array of strings`);
    }
  }
  return values;
}
