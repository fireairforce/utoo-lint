#!/usr/bin/env node
import { spawnSync } from "node:child_process";

import { resolveBinary } from "../lib/binary.js";

if (process.argv[2] === "migrate") {
  const { runMigrate } = await import("./migrate.js");
  process.exit(await runMigrate(process.argv.slice(3)));
}

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
