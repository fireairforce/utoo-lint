#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

import { resolveBinary } from "../lib/binary.js";

const localLintStaged = join(
  process.cwd(),
  "node_modules",
  ".bin",
  process.platform === "win32" ? "lint-staged.cmd" : "lint-staged"
);

if (existsSync(localLintStaged)) {
  const result = spawnSync(localLintStaged, process.argv.slice(2), { stdio: "inherit" });
  if (result.error) {
    console.error(`utoo-lint: failed to run lint-staged: ${result.error.message}`);
    process.exit(1);
  }
  process.exit(result.status ?? 1);
}

const staged = spawnSync("git", ["diff", "--name-only", "--cached", "--diff-filter=ACMRTUB"], {
  encoding: "utf8"
});

if (staged.error) {
  console.error(`utoo-lint: failed to read staged files: ${staged.error.message}`);
  process.exit(1);
}
if (staged.status !== 0) {
  process.stderr.write(staged.stderr ?? "");
  process.exit(staged.status ?? 1);
}

const files = staged.stdout
  .split(/\r?\n/)
  .filter((file) => file.length > 0 && isLintableScript(file));

if (files.length === 0) {
  process.exit(0);
}

let binary;
try {
  binary = resolveBinary();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

const result = spawnSync(binary, files, { stdio: "inherit" });

if (result.error) {
  console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);

function isLintableScript(file) {
  return /\.(?:[cm]?[jt]sx?)$/.test(file);
}
