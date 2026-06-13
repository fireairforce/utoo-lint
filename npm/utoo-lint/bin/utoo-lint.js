#!/usr/bin/env node
import { spawnSync } from "node:child_process";

import { resolveBinary } from "../lib/binary.js";

let binary;
try {
  binary = resolveBinary();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

const result = spawnSync(binary, process.argv.slice(2), { stdio: "inherit" });

if (result.error) {
  console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
