import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, extname, resolve as resolvePath } from "node:path";
import { pathToFileURL } from "node:url";

import { Linter } from "../index.js";

const ESLINT_CONFIG_FILENAMES = [
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  ".eslintrc.json",
  ".eslintrc"
];
const JAVASCRIPT_CONFIG_EXTENSIONS = new Set([".js", ".mjs", ".cjs"]);
const IGNORED_RULES = new Map([
  ["prettier/prettier", "formatting is outside utoo-lint"]
]);
const RULE_ALIASES = new Map([
  ["@eslint-react/no-array-index-key", "react/no-array-index-key"],
  ["@eslint-react/dom-no-find-dom-node", "react/no-find-dom-node"],
  ["@eslint-react/dom-no-render-return-value", "react/no-render-return-value"],
  ["@eslint-react/dom-no-void-elements-with-children", "react/void-dom-elements-no-children"],
  ["@eslint-react/rules-of-hooks", "react-hooks/rules-of-hooks"]
]);
const SCHEMA_URL = "https://raw.githubusercontent.com/utooland/utoo-lint/main/npm/utoo-lint/schema.json";
const JAVASCRIPT_CONFIG_LOADER_SCRIPT = `
import { writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const loaded = await import(pathToFileURL(process.argv[1]).href);
const seen = new Set();

function strip(value) {
  if (value === null || typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return value;
  }
  if (typeof value === "function" || typeof value === "symbol" || typeof value === "undefined") {
    return undefined;
  }
  if (typeof value !== "object") {
    return undefined;
  }
  if (seen.has(value)) {
    return undefined;
  }
  seen.add(value);
  if (Array.isArray(value)) {
    const items = value.map(strip).filter((item) => item !== undefined);
    seen.delete(value);
    return items;
  }
  const object = {};
  for (const [key, item] of Object.entries(value)) {
    const stripped = strip(item);
    if (stripped !== undefined) {
      object[key] = stripped;
    }
  }
  seen.delete(value);
  return object;
}

const json = JSON.stringify(strip(loaded.default ?? loaded));
if (json === undefined) {
  throw new TypeError("config did not export a migratable value");
}
writeFileSync(3, json);
`;

export async function runMigrate(args) {
  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    printMigrateHelp();
    return 0;
  }

  const source = args[0];
  if (source !== "eslint") {
    console.error(`utoo-lint migrate: unsupported source "${source}"`);
    console.error("Supported sources: eslint");
    return 2;
  }

  let options;
  try {
    options = parseEslintMigrateArgs(args.slice(1));
  } catch (error) {
    console.error(error.message);
    return 2;
  }

  if (options.help) {
    printEslintMigrateHelp();
    return 0;
  }

  let result;
  try {
    result = migrateEslintConfig(options);
  } catch (error) {
    console.error(error.message);
    return 2;
  }

  const configJson = JSON.stringify(result.config, null, 2) + "\n";
  if (options.print) {
    process.stdout.write(configJson);
  } else {
    if (existsSync(options.output) && !options.force) {
      console.error(`utoo-lint migrate eslint: ${options.output} already exists; pass --force to overwrite it`);
      return 2;
    }
    writeFileSync(options.output, configJson);
  }

  writeReport(result.report, options, options.print ? process.stderr : process.stdout);
  return result.report.unsupportedRules.length > 0 ? 1 : 0;
}

function parseEslintMigrateArgs(args) {
  const options = {
    cwd: process.cwd(),
    force: false,
    from: undefined,
    help: false,
    output: "utlint.config.json",
    print: false,
    report: "text"
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--help" || arg === "-h") {
      options.help = true;
    } else if (arg === "--force") {
      options.force = true;
    } else if (arg === "--print") {
      options.print = true;
    } else if (arg === "--from") {
      options.from = requireValue(args, ++index, "--from");
    } else if (arg.startsWith("--from=")) {
      options.from = arg.slice("--from=".length);
    } else if (arg === "--output" || arg === "-o") {
      options.output = requireValue(args, ++index, arg);
    } else if (arg.startsWith("--output=")) {
      options.output = arg.slice("--output=".length);
    } else if (arg === "--report") {
      options.report = parseReportFormat(requireValue(args, ++index, "--report"));
    } else if (arg.startsWith("--report=")) {
      options.report = parseReportFormat(arg.slice("--report=".length));
    } else {
      throw new Error(`utoo-lint migrate eslint: unknown option ${arg}`);
    }
  }

  options.cwd = resolvePath(options.cwd);
  options.output = resolvePath(options.cwd, options.output);
  if (options.from) {
    options.from = resolvePath(options.cwd, options.from);
  }
  return options;
}

function requireValue(args, index, flag) {
  const value = args[index];
  if (!value) {
    throw new Error(`utoo-lint migrate eslint: ${flag} requires a value`);
  }
  return value;
}

function parseReportFormat(value) {
  if (value === "text" || value === "json") {
    return value;
  }
  throw new Error(`utoo-lint migrate eslint: unsupported --report value ${value}`);
}

function migrateEslintConfig(options) {
  const sourcePath = options.from ?? findEslintConfig(options.cwd);
  if (!sourcePath) {
    throw new Error("utoo-lint migrate eslint: no ESLint config found; pass --from PATH");
  }

  const eslintConfig = loadEslintConfig(sourcePath, options.cwd);
  const supportedRuleIds = new Set(new Linter().getRules().keys());
  const entries = normalizeConfigEntries(eslintConfig);
  const rules = {};
  const files = new Set();
  const ignores = new Set();
  const supportedRules = [];
  const unsupportedRules = [];
  const ignoredRules = [];
  const translatedRules = [];

  for (const entry of entries) {
    addPatterns(files, entry.files);
    addPatterns(ignores, entry.ignores);
    if (!entry.rules || typeof entry.rules !== "object") {
      continue;
    }
    for (const [ruleId, ruleConfig] of Object.entries(entry.rules)) {
      const migratedRuleId = RULE_ALIASES.get(ruleId) ?? ruleId;
      if (IGNORED_RULES.has(ruleId)) {
        ignoredRules.push({ ruleId, reason: IGNORED_RULES.get(ruleId) });
        continue;
      }
      if (!supportedRuleIds.has(migratedRuleId)) {
        unsupportedRules.push(ruleId);
        continue;
      }
      rules[migratedRuleId] = migratableRuleConfig(ruleConfig);
      supportedRules.push(migratedRuleId);
      if (migratedRuleId !== ruleId) {
        translatedRules.push({ sourceRuleId: ruleId, targetRuleId: migratedRuleId });
      }
    }
  }

  const config = {
    $schema: SCHEMA_URL
  };
  if (files.size > 0) {
    config.files = [...files];
  }
  if (ignores.size > 0) {
    config.ignores = [...ignores];
  }
  config.rules = sortObjectByKey(rules);

  return {
    config,
    report: {
      source: sourcePath,
      output: options.print ? null : options.output,
      supportedRules: uniqueSorted(supportedRules),
      unsupportedRules: uniqueSorted(unsupportedRules),
      ignoredRules: uniqueByRuleId(ignoredRules),
      translatedRules: uniqueTranslatedRules(translatedRules),
      optionDroppedRules: []
    }
  };
}

function findEslintConfig(cwd) {
  let current = cwd;
  while (true) {
    for (const filename of ESLINT_CONFIG_FILENAMES) {
      const candidate = resolvePath(current, filename);
      if (existsSync(candidate)) {
        return candidate;
      }
    }
    const parent = dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}

function loadEslintConfig(path, cwd) {
  if (JAVASCRIPT_CONFIG_EXTENSIONS.has(extname(path))) {
    const result = spawnSync(process.execPath, ["--input-type=module", "--eval", JAVASCRIPT_CONFIG_LOADER_SCRIPT, path], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe", "pipe"]
    });
    if (result.error) {
      throw result.error;
    }
    if (result.status !== 0) {
      throw new Error(`utoo-lint migrate eslint: unable to load ${path}: ${(result.stderr ?? "").trim() || "JavaScript config loader failed"}`);
    }
    return parseJson(result.output?.[3] ?? "", path);
  }
  return parseJson(readFileSync(path, "utf8"), path);
}

function parseJson(source, path) {
  try {
    return JSON.parse(source);
  } catch (error) {
    throw new Error(`utoo-lint migrate eslint: unable to parse ${path}: ${error.message}`);
  }
}

function normalizeConfigEntries(config) {
  if (Array.isArray(config)) {
    return config.flatMap(normalizeConfigEntries);
  }
  if (config && typeof config === "object") {
    return [config];
  }
  return [];
}

function addPatterns(target, value) {
  if (!value) {
    return;
  }
  for (const pattern of Array.isArray(value) ? value : [value]) {
    if (typeof pattern === "string") {
      target.add(pattern);
    }
  }
}

function migratableRuleConfig(ruleConfig) {
  return Array.isArray(ruleConfig) ? [...ruleConfig] : ruleConfig;
}

function sortObjectByKey(object) {
  return Object.fromEntries(Object.entries(object).sort(([left], [right]) => left.localeCompare(right)));
}

function uniqueSorted(values) {
  return [...new Set(values)].sort();
}

function uniqueByRuleId(values) {
  const result = new Map();
  for (const value of values) {
    result.set(value.ruleId, value);
  }
  return [...result.values()].sort((left, right) => left.ruleId.localeCompare(right.ruleId));
}

function uniqueTranslatedRules(values) {
  const result = new Map();
  for (const value of values) {
    result.set(value.sourceRuleId, value);
  }
  return [...result.values()].sort((left, right) => left.sourceRuleId.localeCompare(right.sourceRuleId));
}

function writeReport(report, options, stream) {
  if (options.report === "json") {
    stream.write(JSON.stringify(report, null, 2) + "\n");
    return;
  }

  stream.write(`utoo-lint migrate eslint: read ${pathToFileURL(report.source).href}\n`);
  if (report.output) {
    stream.write(`utoo-lint migrate eslint: wrote ${report.output}\n`);
  }
  stream.write(`utoo-lint migrate eslint: migrated ${report.supportedRules.length} supported rule(s)\n`);
  if (report.translatedRules.length > 0) {
    stream.write(`utoo-lint migrate eslint: translated ${report.translatedRules.length} rule alias(es): ${report.translatedRules.map((rule) => `${rule.sourceRuleId} -> ${rule.targetRuleId}`).join(", ")}\n`);
  }
  if (report.ignoredRules.length > 0) {
    stream.write(`utoo-lint migrate eslint: ignored ${report.ignoredRules.length} rule(s): ${report.ignoredRules.map((rule) => rule.ruleId).join(", ")}\n`);
  }
  if (report.unsupportedRules.length > 0) {
    stream.write(`utoo-lint migrate eslint: ${report.unsupportedRules.length} unsupported rule(s): ${report.unsupportedRules.join(", ")}\n`);
  }
}

function printMigrateHelp() {
  console.log(`Usage:
  utoo-lint migrate eslint [options]

Sources:
  eslint                  Convert an ESLint config into utlint.config.json

Run "utoo-lint migrate eslint --help" for source-specific options.`);
}

function printEslintMigrateHelp() {
  console.log(`Usage:
  utoo-lint migrate eslint [options]

Options:
  --from=PATH             Read ESLint config from PATH
  --output=PATH, -o PATH  Write utoo config to PATH (default: utlint.config.json)
  --force                 Overwrite the output file when it exists
  --print                 Print the generated config instead of writing it
  --report=text|json      Select migration report format
  --help, -h              Show this help message`);
}
