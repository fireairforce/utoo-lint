#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const fishlint = fileURLToPath(new URL("./fishlint.js", import.meta.url));
const result = spawnSync(process.execPath, [fishlint, "eslint", ...process.argv.slice(2)], {
  stdio: "inherit"
});

if (result.error) {
  console.error(`utoo-lint: failed to run eslint compatibility wrapper: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
