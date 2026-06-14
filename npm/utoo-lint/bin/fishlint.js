#!/usr/bin/env node
import { spawnSync } from "node:child_process";

import { resolveBinary } from "../lib/binary.js";
import { translateFishlintArgs } from "../index.js";

let binary;
try {
  binary = resolveBinary();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

let args;
try {
  args = translateFishlintArgs(process.argv.slice(2), {
    warn(message) {
      console.warn(message);
    }
  });
} catch (error) {
  console.error(error.message);
  process.exit(2);
}

const result = spawnSync(binary, args, { stdio: "inherit" });

if (result.error) {
  console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
