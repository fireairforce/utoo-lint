#!/usr/bin/env node

import { runCli } from "../index.js";

if (process.argv[2] === "migrate") {
  const { runMigrate } = await import("./migrate.js");
  process.exitCode = await runMigrate(process.argv.slice(3));
} else {
  let result;
  try {
    result = runCli(process.argv.slice(2), { stdio: "inherit" });
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }

  if (result?.error) {
    console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
    process.exitCode = 1;
  } else if (result) {
    process.exitCode = result.status ?? 1;
  }
}
