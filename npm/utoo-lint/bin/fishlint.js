#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, join } from "node:path";

import { resolveBinary } from "../lib/binary.js";
import { translateFishlintArgs } from "../index.js";

const values = process.argv.slice(2);
const command = values[0];

if (command === "setup" || command === "setuplint") {
  console.warn(`utoo-lint: fishlint ${command} is treated as a no-op; configure utoo-lint with utoo.json.`);
  process.exit(0);
}

if (command && command !== "eslint") {
  runDelegatedCommand(command, values.slice(1));
}

let args;
const output = extractOutputFile(values);
const input = extractStdin(output.args);
const nativeValues = input.file ? [...input.args, input.file] : input.args;
try {
  args = translateFishlintArgs(nativeValues, {
    warn(message) {
      console.warn(message);
    }
  });
} catch (error) {
  console.error(error.message);
  process.exit(2);
}

let binary;
try {
  binary = resolveBinary();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

const shouldCapture = Boolean(output.file || input.displayPath);
const result = spawnSync(binary, args, shouldCapture ? { encoding: "utf8" } : { stdio: "inherit" });

if (result.error) {
  console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
  cleanupStdinInput(input);
  process.exit(1);
}
if (shouldCapture) {
  const stdout = rewriteStdinPath(result.stdout ?? "", input);
  const stderr = rewriteStdinPath(result.stderr ?? "", input);
  if (stderr) {
    process.stderr.write(stderr);
  }
  if (output.file) {
    writeFileSync(output.file, stdout);
  } else if (stdout) {
    process.stdout.write(stdout);
  }
}

cleanupStdinInput(input);
process.exit(result.status ?? 1);

function extractOutputFile(args) {
  const values = [];
  let file;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--output-file" || arg === "-o") {
      file = args[index + 1];
      if (!file) {
        console.error(`utoo-lint: fishlint ${arg} requires a path`);
        process.exit(2);
      }
      index += 1;
      continue;
    }
    if (arg.startsWith("--output-file=")) {
      file = arg.slice("--output-file=".length);
      continue;
    }
    values.push(arg);
  }

  return { args: values, file };
}

function extractStdin(args) {
  const values = [];
  let enabled = false;
  let displayPath = "<stdin>";

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--stdin") {
      enabled = true;
      continue;
    }
    if (arg === "--stdin-filename") {
      displayPath = args[index + 1];
      if (!displayPath) {
        console.error("utoo-lint: fishlint --stdin-filename requires a path");
        process.exit(2);
      }
      index += 1;
      continue;
    }
    if (arg.startsWith("--stdin-filename=")) {
      displayPath = arg.slice("--stdin-filename=".length);
      continue;
    }
    values.push(arg);
  }

  if (!enabled) {
    return { args: values };
  }

  const directory = mkdtempSync(join(tmpdir(), "utoo-fishlint-stdin-"));
  const extension = extname(displayPath) || ".js";
  const file = join(directory, `stdin${extension}`);
  writeFileSync(file, readFileSync(0, "utf8"));
  return { args: values, directory, displayPath, file };
}

function rewriteStdinPath(text, input) {
  if (!input.file || !input.displayPath) {
    return text;
  }
  return text.split(input.file).join(input.displayPath);
}

function cleanupStdinInput(input) {
  if (input.directory) {
    rmSync(input.directory, { recursive: true, force: true });
  }
}

function runDelegatedCommand(command, args) {
  const delegated = delegatedCommand(command, args);
  if (!delegated) {
    console.error(`utoo-lint fishlint compatibility only supports the eslint command, received: ${command}`);
    process.exit(2);
  }

  const bin = localBin(delegated.bin);
  if (!bin) {
    console.error(`utoo-lint: fishlint ${command} requires a project-local ${delegated.bin} binary`);
    process.exit(2);
  }

  const result = spawnSync(bin, delegated.args, { stdio: "inherit" });
  if (result.error) {
    console.error(`utoo-lint: failed to run ${delegated.bin}: ${result.error.message}`);
    process.exit(1);
  }
  process.exit(result.status ?? 1);
}

function delegatedCommand(command, args) {
  switch (command) {
    case "stylelint":
      return {
        bin: "stylelint",
        args: withDefaultTargets(
          translatePassthroughArgs(args, {
            passthroughFlags: new Set(["--fix", "--quiet"])
          }),
          ["**/*.{less,css,acss}"]
        )
      };
    case "format":
      return {
        bin: "prettier",
        args: ["--write", ...withDefaultTargets(translatePassthroughArgs(args), ["**/*.{js,jsx,ts,tsx,less,css,vue}"])]
      };
    case "commitlint":
      return {
        bin: "commitlint",
        args: translateCommitlintArgs(args)
      };
    case "projectlint":
      return {
        bin: "projectlint",
        args: ["lint", "./", ...translatePassthroughArgs(args, { passthroughFlags: new Set(["--debug"]) })]
      };
    default:
      return null;
  }
}

function withDefaultTargets(args, defaults) {
  if (args.some((arg) => !arg.startsWith("-"))) {
    return args;
  }
  return [...args, ...defaults];
}

function translatePassthroughArgs(args, options = {}) {
  const passthroughFlags = options.passthroughFlags ?? new Set();
  const dropValueFlags = options.dropValueFlags ?? new Set();
  const translated = [];
  const targets = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--") continue;
    if (arg === "--disable-setup" || arg === "--disable-legacy" || arg === "--verbose" || arg === "-v") continue;
    if (arg === "--glob") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --glob requires a path");
        process.exit(2);
      }
      targets.push(value);
      index += 1;
      continue;
    }
    if (arg.startsWith("--glob=")) {
      targets.push(arg.slice("--glob=".length));
      continue;
    }
    if (dropValueFlags.has(arg)) {
      index += 1;
      continue;
    }
    if ([...dropValueFlags].some((flag) => arg.startsWith(`${flag}=`))) {
      continue;
    }
    if (passthroughFlags.has(arg) || [...passthroughFlags].some((flag) => arg.startsWith(`${flag}=`))) {
      translated.push(arg);
      continue;
    }
    translated.push(arg);
  }

  translated.push(...targets);
  return translated;
}

function translateCommitlintArgs(args) {
  const translated = [];
  let hasMessageSource = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--quiet") {
      translated.push(arg);
      continue;
    }
    if (arg === "-E" || arg === "--env") {
      const envKey = args[index + 1];
      if (!envKey) {
        console.error(`utoo-lint: fishlint ${arg} requires an environment variable name`);
        process.exit(2);
      }
      if (process.env[envKey]) {
        translated.push("--env", envKey);
      } else {
        translated.push("--edit");
      }
      hasMessageSource = true;
      index += 1;
      continue;
    }
    if (arg.startsWith("--env=")) {
      const envKey = arg.slice("--env=".length);
      if (process.env[envKey]) {
        translated.push("--env", envKey);
      } else {
        translated.push("--edit");
      }
      hasMessageSource = true;
      continue;
    }
    translated.push(arg);
  }

  if (!hasMessageSource) {
    translated.push("--edit");
  }
  return translated;
}

function localBin(name) {
  const executable = process.platform === "win32" ? `${name}.cmd` : name;
  const path = join(process.cwd(), "node_modules", ".bin", executable);
  return existsSync(path) ? path : null;
}
