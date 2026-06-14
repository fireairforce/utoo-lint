#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, join } from "node:path";

import { resolveBinary } from "../lib/binary.js";
import { translateFishlintArgs, version } from "../index.js";

const values = process.argv.slice(2);
const command = values[0];
const TARGET_VALUE_FLAGS = new Set([
  "--cache-location",
  "--cache-strategy",
  "--config",
  "--env",
  "--ext",
  "--fix-type",
  "--format",
  "--global",
  "--ignore-path",
  "--ignore-pattern",
  "--max-warnings",
  "--output-file",
  "--parser",
  "--parser-options",
  "--plugin",
  "--print-config",
  "--resolve-plugins-relative-to",
  "--rule",
  "--rules",
  "--rulesdir",
  "--stdin-filename",
  "--threads",
  "-c",
  "-E",
  "-f",
  "-o"
]);
const FISHLINT_PASSTHROUGH_DROP_FLAGS = new Set([
  "--disable-legacy",
  "--disable-setup",
  "--verbose",
  "-v"
]);
const FORMAT_VALUE_FLAGS = new Set(["--config", "--ignore-path", "--parser", "--plugin"]);
const CONFIG_FILENAMES = ["utoo.json", "utoo-lint.json", "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs"];
const JAVASCRIPT_CONFIG_EXTENSIONS = new Set([".js", ".mjs", ".cjs"]);
const JAVASCRIPT_CONFIG_LOADER_SCRIPT = `
import { pathToFileURL } from "node:url";

const configPath = process.argv[1];
const loaded = await import(pathToFileURL(configPath).href);
const value = loaded.default ?? loaded;
const json = JSON.stringify(value);
if (json === undefined) {
  throw new TypeError("config did not export a JSON-serializable value");
}
process.stdout.write(json);
`;
const STYLELINT_VALUE_FLAGS = new Set([
  "--cache-location",
  "--config",
  "--custom-syntax",
  "--formatter",
  "--ignore-path",
  "--output-file",
  "-c",
  "-f",
  "-o"
]);

if (isVersionRequest(values)) {
  printVersion();
  process.exit(0);
}

if (isHelpRequest(values)) {
  runNativeHelp();
}

if (command === "setup" || command === "setuplint") {
  console.warn(`utoo-lint: fishlint ${command} is treated as a no-op; configure utoo-lint with utoo.json.`);
  process.exit(0);
}

if (command && command !== "eslint") {
  runDelegatedCommand(command, values.slice(1));
}

if (isVersionRequest(values.slice(1))) {
  printVersion();
  process.exit(0);
}

let args;
const output = extractOutputFile(values);
const ignored = extractIgnorePatterns(output.args);
const globExpanded = expandGlobTargets(ignored.args);
const maxWarnings = extractMaxWarnings(globExpanded.args);
const ruleOverrides = extractRuleOverrides(maxWarnings.args);
const quiet = extractQuiet(ruleOverrides.args);
const printConfig = extractPrintConfig(quiet.args);
if (printConfig.enabled) {
  writeOutput(JSON.stringify(loadPrintableConfig(printConfig.args, ruleOverrides.rules), null, 2) + "\n", output.file);
  process.exit(0);
}

const warnIgnored = extractWarnIgnoredOption(printConfig.args);
const unmatched = extractUnmatchedPatternOption(warnIgnored.args);
const ignoredFiltered = filterIgnoredTargets(unmatched.args, ignored.patterns, warnIgnored.enabled);
const filtered = filterUnmatchedTargets(ignoredFiltered.args, unmatched.enabled);
const input = extractStdin(filtered.args);
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
if (args.length === 0) {
  const report = emptyLintReport(ignoredFiltered.diagnostics);
  writeOutput(formatReportOutput(report, nativeValues), output.file);
  cleanupStdinInput(input);
  process.exit(eslintExitStatusFromCounts(diagnosticCountsFromReport(report), maxWarnings.value));
}
if ((ignoredFiltered.removedTarget || filtered.removedTarget) && !hasLintTarget(nativeValues)) {
  const report = emptyLintReport(ignoredFiltered.diagnostics);
  writeOutput(formatReportOutput(report, nativeValues), output.file);
  cleanupStdinInput(input);
  process.exit(eslintExitStatusFromCounts(diagnosticCountsFromReport(report), maxWarnings.value));
}

let binary;
try {
  binary = resolveBinary();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

const printableConfig = loadPrintableConfig(nativeValues, ruleOverrides.rules);
const ruleSeverities = ruleSeverityMap(printableConfig.rules);
const ruleConfig = materializeRuntimeConfig(nativeValues, args, ruleOverrides.rules);
const needsReportOutput =
  quiet.enabled ||
  ignoredFiltered.diagnostics.length > 0 ||
  usesJsonWithMetadataFormat(nativeValues) ||
  ruleSeverities.size > 0;
const result = spawnSync(binary, needsReportOutput ? withJsonFormat(ruleConfig.args) : ruleConfig.args, { encoding: "utf8" });

if (result.error) {
  console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
  cleanupRuleConfig(ruleConfig);
  cleanupStdinInput(input);
  process.exit(1);
}
const rawStdout = result.stdout ?? "";
const stderr = rewriteStdinPath(result.stderr ?? "", input);
if (stderr) {
  process.stderr.write(stderr);
}

let exitStatus;
if (needsReportOutput) {
  const report = parseJsonReport(rawStdout);
  if (!report) {
    writeOutput(rewriteStdinPath(rawStdout, input), output.file);
    exitStatus = result.status ?? 1;
  } else {
    const reportWithSeverity = normalizeReportSeverities(report, ruleSeverities);
    const reportWithIgnored = appendDiagnostics(reportWithSeverity, ignoredFiltered.diagnostics);
    const filteredReport = quiet.enabled ? filterQuietReport(reportWithIgnored) : reportWithIgnored;
    const rewrittenReport = rewriteReportStdinPaths(filteredReport, input);
    writeOutput(formatReportOutput(rewrittenReport, nativeValues), output.file);
    exitStatus = eslintExitStatusFromCounts(diagnosticCountsFromReport(rewrittenReport), maxWarnings.value);
  }
} else {
  writeOutput(rewriteStdinPath(rawStdout, input), output.file);
  exitStatus = eslintExitStatus(binary, ruleConfig.args, result.status ?? 1, rawStdout, maxWarnings.value);
}
cleanupRuleConfig(ruleConfig);
cleanupStdinInput(input);
process.exit(exitStatus);

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

function extractIgnorePatterns(args) {
  const values = [];
  const patterns = [];
  let ignorePath = ".eslintignore";
  let ignorePathEnabled = true;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--ignore-path") {
      ignorePath = args[index + 1];
      if (!ignorePath) {
        console.error("utoo-lint: fishlint --ignore-path requires a path");
        process.exit(2);
      }
      index += 1;
      continue;
    }
    if (arg.startsWith("--ignore-path=")) {
      ignorePath = arg.slice("--ignore-path=".length);
      continue;
    }
    if (arg === "--no-ignore") {
      ignorePathEnabled = false;
      continue;
    }
    if (arg.startsWith("--no-ignore=")) {
      ignorePathEnabled = booleanFlagValue(arg) === false;
      continue;
    }
    if (arg === "--no-eslintrc") {
      values.push("--no-config");
      continue;
    }
    if (arg.startsWith("--no-eslintrc=")) {
      if (booleanFlagValue(arg) !== false) {
        values.push("--no-config");
      }
      continue;
    }
    if (arg === "--ignore-pattern") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --ignore-pattern requires a pattern");
        process.exit(2);
      }
      patterns.push(value);
      index += 1;
      continue;
    }
    if (arg.startsWith("--ignore-pattern=")) {
      patterns.push(arg.slice("--ignore-pattern=".length));
      continue;
    }
    values.push(arg);
  }

  if (!ignorePathEnabled) {
    return { args: values, patterns: [] };
  }

  patterns.push(...readIgnoreFile(ignorePath));
  return { args: values, patterns };
}

function extractMaxWarnings(args) {
  const values = [];
  let maxWarnings;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--max-warnings") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --max-warnings requires a number");
        process.exit(2);
      }
      maxWarnings = parseMaxWarnings(value);
      index += 1;
      continue;
    }
    if (arg.startsWith("--max-warnings=")) {
      maxWarnings = parseMaxWarnings(arg.slice("--max-warnings=".length));
      continue;
    }
    values.push(arg);
  }

  return { args: values, value: maxWarnings };
}

function extractQuiet(args) {
  const values = [];
  let enabled = false;

  for (const arg of args) {
    if (arg === "--quiet") {
      enabled = true;
      continue;
    }
    if (arg.startsWith("--quiet=")) {
      enabled = booleanFlagValue(arg) !== false;
      continue;
    }
    values.push(arg);
  }

  return { args: values, enabled };
}

function extractUnmatchedPatternOption(args) {
  const values = [];
  let enabled = false;

  for (const arg of args) {
    if (arg === "--no-error-on-unmatched-pattern") {
      enabled = true;
      continue;
    }
    if (arg.startsWith("--no-error-on-unmatched-pattern=")) {
      enabled = booleanFlagValue(arg) !== false;
      continue;
    }
    values.push(arg);
  }

  return { args: values, enabled };
}

function extractWarnIgnoredOption(args) {
  const values = [];
  let enabled = true;

  for (const arg of args) {
    if (arg === "--no-warn-ignored") {
      enabled = false;
      continue;
    }
    if (arg.startsWith("--no-warn-ignored=")) {
      enabled = booleanFlagValue(arg) === false;
      continue;
    }
    values.push(arg);
  }

  return { args: values, enabled };
}

function extractRuleOverrides(args) {
  const values = [];
  const rules = {};

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--rule") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --rule requires a rule configuration");
        process.exit(2);
      }
      Object.assign(rules, parseRuleOverride(value));
      index += 1;
      continue;
    }
    if (arg.startsWith("--rule=")) {
      Object.assign(rules, parseRuleOverride(arg.slice("--rule=".length)));
      continue;
    }
    values.push(arg);
  }

  return { args: values, rules };
}

function parseRuleOverride(value) {
  const trimmed = value.trim();
  if (!trimmed) {
    console.error("utoo-lint: fishlint --rule requires a non-empty rule configuration");
    process.exit(2);
  }

  if (trimmed.startsWith("{")) {
    try {
      const parsed = JSON.parse(trimmed);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return parsed;
      }
    } catch {}
    console.error(`utoo-lint: fishlint --rule must be a JSON object or rule: severity pair: ${value}`);
    process.exit(2);
  }

  const separator = trimmed.indexOf(":");
  if (separator === -1) {
    console.error(`utoo-lint: fishlint --rule must include a ':' separator: ${value}`);
    process.exit(2);
  }

  const rule = trimmed.slice(0, separator).trim();
  const rawConfig = trimmed.slice(separator + 1).trim();
  if (!rule || !rawConfig) {
    console.error(`utoo-lint: fishlint --rule must include both rule name and severity: ${value}`);
    process.exit(2);
  }

  return { [rule]: parseRuleValue(rawConfig) };
}

function parseRuleValue(value) {
  if (value.startsWith("[") || value.startsWith("{") || value.startsWith('"')) {
    try {
      return JSON.parse(value);
    } catch {}
  }
  if (/^-?\d+$/.test(value)) {
    return Number(value);
  }
  return value;
}

function ruleSeverityMap(rules) {
  const severities = new Map();
  if (!rules || typeof rules !== "object") {
    return severities;
  }

  for (const [rule, config] of Object.entries(rules)) {
    severities.set(rule, ruleConfigSeverity(config));
  }
  return severities;
}

function ruleConfigSeverity(config) {
  const severity = Array.isArray(config) ? config[0] : config;
  if (severity === false || severity === 0) return 0;
  if (severity === true || severity === 2) return 2;
  if (severity === 1) return 1;
  if (typeof severity === "string") {
    switch (severity.toLowerCase()) {
      case "off":
      case "0":
        return 0;
      case "warn":
      case "warning":
      case "1":
        return 1;
      case "error":
      case "2":
        return 2;
      default:
        return 1;
    }
  }
  return 1;
}

function parseMaxWarnings(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < -1) {
    console.error(`utoo-lint: fishlint --max-warnings must be an integer greater than or equal to -1: ${value}`);
    process.exit(2);
  }
  return parsed;
}

function booleanFlagValue(arg) {
  const value = arg.slice(arg.indexOf("=") + 1).trim().toLowerCase();
  if (value === "false" || value === "0") {
    return false;
  }
  return true;
}

function readIgnoreFile(path) {
  if (!path || !existsSync(path)) {
    return [];
  }

  return readFileSync(path, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}

function expandGlobTargets(args) {
  const values = [];
  const excludedPatterns = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (TARGET_VALUE_FLAGS.has(arg)) {
      values.push(arg);
      if (index + 1 < args.length) {
        values.push(args[index + 1]);
        index += 1;
      }
      continue;
    }
    if (arg === "--glob") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --glob requires a path");
        process.exit(2);
      }
      if (isNegatedGlobTarget(value)) {
        excludedPatterns.push(value.slice(1));
        index += 1;
        continue;
      }
      values.push(...expandedGlobOrOriginal(value, [arg, value]));
      index += 1;
      continue;
    }
    if (arg.startsWith("--glob=")) {
      const value = arg.slice("--glob=".length);
      if (isNegatedGlobTarget(value)) {
        excludedPatterns.push(value.slice(1));
        continue;
      }
      values.push(...expandedGlobOrOriginal(value, [arg]));
      continue;
    }
    values.push(arg);
  }
  return { args: filterExpandedGlobExclusions(values, excludedPatterns) };
}

function isNegatedGlobTarget(value) {
  return value.startsWith("!") && value.length > 1;
}

function filterExpandedGlobExclusions(args, excludedPatterns) {
  if (excludedPatterns.length === 0) {
    return args;
  }

  const values = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (TARGET_VALUE_FLAGS.has(arg)) {
      values.push(arg);
      if (index + 1 < args.length) {
        values.push(args[index + 1]);
        index += 1;
      }
      continue;
    }
    if (index > 0 && !arg.startsWith("-") && isIgnoredTarget(arg, excludedPatterns)) {
      continue;
    }
    values.push(arg);
  }
  return values;
}

function expandedGlobOrOriginal(pattern, original) {
  if (!hasGlobSyntax(pattern)) {
    return original;
  }
  const matches = expandGlobPattern(pattern);
  return matches.length > 0 ? matches : original;
}

function hasGlobSyntax(pattern) {
  return /[*?[\]{}]/.test(pattern);
}

function expandGlobPattern(pattern) {
  const base = globBaseDirectory(pattern);
  if (!base || !existsSync(base)) {
    return [];
  }

  let stat;
  try {
    stat = statSync(base);
  } catch {
    return [];
  }
  if (!stat.isDirectory()) {
    return [];
  }

  const expression = new RegExp(`^${globPatternRegExpSource(normalizePath(pattern))}$`);
  return walkFiles(base)
    .map(normalizePath)
    .filter((file) => expression.test(file));
}

function globBaseDirectory(pattern) {
  const segments = normalizePath(pattern).split("/");
  const baseSegments = [];
  for (const segment of segments) {
    if (hasGlobSyntax(segment)) {
      break;
    }
    baseSegments.push(segment);
  }
  return baseSegments.length > 0 ? baseSegments.join("/") : ".";
}

function walkFiles(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) {
      files.push(...walkFiles(path));
    } else if (entry.isFile()) {
      files.push(path);
    }
  }
  return files;
}

function filterIgnoredTargets(args, patterns, warnIgnored) {
  if (patterns.length === 0) {
    return { args, removedTarget: false, diagnostics: [] };
  }

  const values = [];
  const diagnostics = [];
  let removedTarget = false;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (TARGET_VALUE_FLAGS.has(arg)) {
      values.push(arg);
      if (index + 1 < args.length) {
        values.push(args[index + 1]);
        index += 1;
      }
      continue;
    }
    if (arg === "--glob") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --glob requires a path");
        process.exit(2);
      }
      if (!isIgnoredTarget(value, patterns)) {
        values.push(arg, value);
      } else {
        removedTarget = true;
      }
      index += 1;
      continue;
    }
    if (arg.startsWith("--glob=")) {
      const value = arg.slice("--glob=".length);
      if (!isIgnoredTarget(value, patterns)) {
        values.push(arg);
      } else {
        removedTarget = true;
      }
      continue;
    }
    if (index > 0 && !arg.startsWith("-") && isIgnoredTarget(arg, patterns)) {
      removedTarget = true;
      if (warnIgnored && isExistingLintFile(arg)) {
        diagnostics.push(ignoredTargetDiagnostic(arg));
      }
      continue;
    }
    values.push(arg);
  }
  return { args: values, removedTarget, diagnostics };
}

function filterUnmatchedTargets(args, enabled) {
  if (!enabled) {
    return { args, removedTarget: false };
  }

  const values = [];
  let removedTarget = false;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (TARGET_VALUE_FLAGS.has(arg)) {
      values.push(arg);
      if (index + 1 < args.length) {
        values.push(args[index + 1]);
        index += 1;
      }
      continue;
    }
    if (arg === "--glob") {
      const value = args[index + 1];
      if (!value) {
        console.error("utoo-lint: fishlint --glob requires a path");
        process.exit(2);
      }
      if (existsSync(value)) {
        values.push(arg, value);
      } else {
        removedTarget = true;
      }
      index += 1;
      continue;
    }
    if (arg.startsWith("--glob=")) {
      const value = arg.slice("--glob=".length);
      if (existsSync(value)) {
        values.push(arg);
      } else {
        removedTarget = true;
      }
      continue;
    }
    if (index > 0 && !arg.startsWith("-") && !existsSync(arg)) {
      removedTarget = true;
      continue;
    }
    values.push(arg);
  }
  return { args: values, removedTarget };
}

function hasLintTarget(args) {
  const valueFlags = TARGET_VALUE_FLAGS;

  for (let index = 1; index < args.length; index += 1) {
    const arg = args[index];
    if (valueFlags.has(arg)) {
      index += 1;
      continue;
    }
    if (arg === "--glob") {
      return Boolean(args[index + 1]);
    }
    if (arg.startsWith("--glob=")) {
      return arg.length > "--glob=".length;
    }
    if (arg.includes("=")) {
      continue;
    }
    if (!arg.startsWith("-")) {
      return true;
    }
  }
  return false;
}

function isIgnoredTarget(target, patterns) {
  const normalized = normalizePath(target);
  let ignored = false;
  for (const pattern of patterns) {
    const negated = pattern.startsWith("!");
    if (matchesIgnorePattern(normalized, normalizeIgnoredPattern(pattern))) {
      ignored = !negated;
    }
  }
  return ignored;
}

function normalizeIgnoredPattern(pattern) {
  return normalizePath(pattern.replace(/^!/, "").replace(/^\//, ""));
}

function matchesIgnorePattern(target, pattern) {
  if (pattern.endsWith("/**")) {
    const prefix = pattern.slice(0, -3);
    return target === prefix || target.startsWith(`${prefix}/`) || target.includes(`/${prefix}/`);
  }
  if (pattern.startsWith("**/")) {
    const suffix = pattern.slice(3);
    if (!hasGlobSyntax(suffix)) {
      return target.endsWith(suffix) || target.includes(`/${suffix}`);
    }
  }
  if (!hasGlobSyntax(pattern)) {
    return target === pattern || target.endsWith(`/${pattern}`) || target.startsWith(`${pattern}/`);
  }

  const expression = new RegExp(`(^|/)${globPatternRegExpSource(pattern)}$`);
  return expression.test(target);
}

function normalizePath(path) {
  return path.replaceAll("\\", "/").replace(/^\.\//, "");
}

function globPatternRegExpSource(pattern) {
  let source = "";
  for (let index = 0; index < pattern.length; index += 1) {
    const char = pattern[index];
    if (char === "*") {
      if (pattern[index + 1] === "*") {
        if (pattern[index + 2] === "/") {
          source += "(?:.*/)?";
          index += 2;
        } else {
          source += ".*";
          index += 1;
        }
      } else {
        source += "[^/]*";
      }
      continue;
    }
    if (char === "?") {
      source += "[^/]";
      continue;
    }
    if (char === "{") {
      const end = pattern.indexOf("}", index + 1);
      if (end !== -1) {
        const parts = pattern.slice(index + 1, end).split(",");
        source += `(?:${parts.map(escapeRegExp).join("|")})`;
        index = end;
        continue;
      }
    }
    if (char === "[") {
      const end = pattern.indexOf("]", index + 1);
      if (end !== -1) {
        const raw = pattern.slice(index + 1, end);
        if (raw.length > 0) {
          const negated = raw[0] === "!" || raw[0] === "^";
          const body = raw.slice(negated ? 1 : 0);
          if (body.length > 0) {
            source += `[${negated ? "^" : ""}${escapeCharacterClass(body)}]`;
            index = end;
            continue;
          }
        }
      }
    }
    source += escapeRegExp(char);
  }
  return source;
}

function escapeRegExp(value) {
  return value.replace(/[|\\{}()[\]^$+?.]/g, "\\$&");
}

function escapeCharacterClass(value) {
  return value.replace(/[\\\]]/g, "\\$&");
}

function emptyLintOutput(args) {
  return formatReportOutput(emptyLintReport(), args);
}

function emptyLintReport(diagnostics = []) {
  return { files: 0, filePaths: [], diagnostics };
}

function appendDiagnostics(report, diagnostics) {
  if (diagnostics.length === 0) {
    return report;
  }
  return {
    ...report,
    diagnostics: [...(report.diagnostics ?? []), ...diagnostics]
  };
}

function isExistingLintFile(target) {
  return existsSync(target) && [".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".mts", ".cts"].includes(extname(target));
}

function ignoredTargetDiagnostic(target) {
  return {
    filePath: target,
    line: 0,
    column: 0,
    severity: "warning",
    message: "File ignored because of a matching ignore pattern. Use --no-ignore to override.",
    ruleId: null
  };
}

function usesJsonFormat(args) {
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (
      arg === "--json" ||
      arg === "--format=json" ||
      arg === "--format=json-with-metadata" ||
      arg === "-f=json" ||
      arg === "-f=json-with-metadata"
    ) {
      return true;
    }
    if ((arg === "--format" || arg === "-f") && (args[index + 1] === "json" || args[index + 1] === "json-with-metadata")) {
      return true;
    }
  }
  return false;
}

function usesJsonWithMetadataFormat(args) {
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--format=json-with-metadata" || arg === "-f=json-with-metadata") {
      return true;
    }
    if ((arg === "--format" || arg === "-f") && args[index + 1] === "json-with-metadata") {
      return true;
    }
  }
  return false;
}

function extractPrintConfig(args) {
  const values = [];
  let enabled = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--print-config") {
      if (!args[index + 1]) {
        console.error("utoo-lint: fishlint --print-config requires a file path");
        process.exit(2);
      }
      enabled = true;
      index += 1;
      continue;
    }
    if (arg.startsWith("--print-config=")) {
      enabled = true;
      continue;
    }
    values.push(arg);
  }

  return { args: values, enabled };
}

function loadPrintableConfig(args, ruleOverrides = {}) {
  const configPath = findConfigPath(args);
  const config = configPath ? readConfig(configPath) : {};
  return {
    ...(Array.isArray(config) ? {} : config),
    rules: {
      ...rulesFromConfig(config),
      ...ruleOverrides
    }
  };
}

function materializeRuntimeConfig(args, translatedArgs, ruleOverrides) {
  const configPath = findConfigPath(args);
  const shouldMaterialize = isJavaScriptConfigPath(configPath) || Object.keys(ruleOverrides).length > 0;
  if (!shouldMaterialize) {
    return { args: translatedArgs };
  }

  const directory = mkdtempSync(join(tmpdir(), "utoo-fishlint-rule-"));
  const file = join(directory, "utoo.json");
  writeFileSync(file, JSON.stringify(loadRuntimeConfig(configPath, ruleOverrides)));

  return {
    args: withConfigArg(translatedArgs, file),
    directory
  };
}

function loadRuntimeConfig(configPath, ruleOverrides = {}) {
  const config = configPath ? readConfig(configPath) : {};
  if (Array.isArray(config)) {
    return {
      rules: {
        ...rulesFromConfig(config),
        ...ruleOverrides
      }
    };
  }
  return {
    ...config,
    rules: {
      ...(config.rules ?? {}),
      ...ruleOverrides
    }
  };
}

function readConfig(path) {
  if (isJavaScriptConfigPath(path)) {
    return readJavaScriptConfig(path);
  }

  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    console.error(`utoo-lint: unable to read config ${path}: ${error.message}`);
    process.exit(2);
  }
}

function readJavaScriptConfig(path) {
  const result = spawnSync(process.execPath, ["--input-type=module", "--eval", JAVASCRIPT_CONFIG_LOADER_SCRIPT, path], {
    encoding: "utf8"
  });
  if (result.error) {
    console.error(`utoo-lint: unable to read config ${path}: ${result.error.message}`);
    process.exit(2);
  }
  if (result.status !== 0) {
    console.error(`utoo-lint: unable to read config ${path}: ${(result.stderr ?? "").trim() || "JavaScript config loader failed"}`);
    process.exit(2);
  }
  try {
    return JSON.parse(result.stdout);
  } catch (error) {
    console.error(`utoo-lint: unable to read config ${path}: ${error.message}`);
    process.exit(2);
  }
}

function isJavaScriptConfigPath(path) {
  return typeof path === "string" && JAVASCRIPT_CONFIG_EXTENSIONS.has(extname(path));
}

function rulesFromConfig(config) {
  if (!config) {
    return {};
  }
  if (Array.isArray(config)) {
    return config.reduce((rules, entry) => ({
      ...rules,
      ...rulesFromConfig(entry)
    }), {});
  }
  return config.rules && typeof config.rules === "object" ? config.rules : {};
}

function withConfigArg(args, file) {
  const values = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "-c") {
      index += 1;
      continue;
    }
    if (arg === "--no-config" || arg.startsWith("--config=")) {
      continue;
    }
    values.push(arg);
  }
  values.unshift(`--config=${file}`);
  return values;
}

function findConfigPath(args) {
  let configEnabled = true;
  let configPath;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--no-config" || arg === "--no-eslintrc") {
      configEnabled = false;
      configPath = undefined;
      continue;
    }
    if (arg === "--config" || arg === "-c") {
      configPath = args[index + 1];
      if (!configPath) {
        console.error(`utoo-lint: fishlint ${arg} requires a path`);
        process.exit(2);
      }
      index += 1;
      continue;
    }
    if (arg.startsWith("--config=")) {
      configPath = arg.slice("--config=".length);
    }
  }

  if (!configEnabled) {
    return undefined;
  }
  if (configPath) {
    return configPath;
  }
  for (const candidate of CONFIG_FILENAMES) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }
  return undefined;
}

function writeOutput(text, file) {
  if (file) {
    writeFileSync(file, text);
  } else if (text) {
    process.stdout.write(text);
  }
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

function cleanupRuleConfig(config) {
  if (config.directory) {
    rmSync(config.directory, { recursive: true, force: true });
  }
}

function eslintExitStatus(binary, args, status, stdout, maxWarnings) {
  if (status !== 0 && status !== 1) {
    return status;
  }

  const counts = diagnosticCounts(stdout) ?? (status === 1 ? jsonDiagnosticCounts(binary, args) : null);
  if (!counts) {
    return status;
  }
  return eslintExitStatusFromCounts(counts, maxWarnings);
}

function eslintExitStatusFromCounts(counts, maxWarnings) {
  if (counts.errors > 0) {
    return 1;
  }
  if (maxWarnings != null && maxWarnings >= 0 && counts.warnings > maxWarnings) {
    console.error(
      `utoo-lint: fishlint found too many warnings (maximum: ${maxWarnings}, found: ${counts.warnings}).`
    );
    return 1;
  }
  return 0;
}

function diagnosticCounts(stdout) {
  return diagnosticCountsFromReport(parseJsonReport(stdout));
}

function diagnosticCountsFromReport(report) {
  if (!Array.isArray(report?.diagnostics)) {
    return null;
  }

  let errors = 0;
  let warnings = 0;
  for (const diagnostic of report.diagnostics) {
    if (diagnostic?.severity === "error") {
      errors += 1;
    } else {
      warnings += 1;
    }
  }
  return { errors, warnings };
}

function parseJsonReport(stdout) {
  try {
    return JSON.parse(stdout);
  } catch {
    return null;
  }
}

function jsonDiagnosticCounts(binary, args) {
  const result = spawnSync(binary, withJsonFormat(args), { encoding: "utf8" });
  if (result.error) {
    return null;
  }
  return diagnosticCounts(result.stdout ?? "");
}

function withJsonFormat(args) {
  const values = [];
  let foundFormat = false;

  for (const arg of args) {
    if (arg === "--json") {
      foundFormat = true;
      values.push(arg);
      continue;
    }
    if (arg.startsWith("--format=")) {
      foundFormat = true;
      values.push("--format=json");
      continue;
    }
    values.push(arg);
  }

  if (!foundFormat) {
    values.unshift("--format=json");
  }
  return values;
}

function filterQuietReport(report) {
  return {
    ...report,
    diagnostics: (report.diagnostics ?? []).filter((diagnostic) => diagnostic?.severity === "error")
  };
}

function normalizeReportSeverities(report, ruleSeverities) {
  if (ruleSeverities.size === 0) {
    return report;
  }

  return {
    ...report,
    diagnostics: (report.diagnostics ?? []).flatMap((diagnostic) => {
      if (!diagnostic?.ruleId) {
        return [diagnostic];
      }

      const severity = ruleSeverities.get(diagnostic.ruleId);
      if (severity === 0) {
        return [];
      }
      if (severity === 1 || severity === 2) {
        return [{ ...diagnostic, severity: severity === 2 ? "error" : "warning" }];
      }
      return [diagnostic];
    })
  };
}

function rewriteReportStdinPaths(report, input) {
  if (!input.file || !input.displayPath) {
    return report;
  }

  return {
    ...report,
    filePaths: (report.filePaths ?? []).map((filePath) => (filePath === input.file ? input.displayPath : filePath)),
    diagnostics: (report.diagnostics ?? []).map((diagnostic) => ({
      ...diagnostic,
      filePath: diagnostic.filePath === input.file ? input.displayPath : diagnostic.filePath
    }))
  };
}

function formatReportOutput(report, args) {
  if (usesJsonWithMetadataFormat(args)) {
    return JSON.stringify(reportWithMetadata(report)) + "\n";
  }
  if (usesJsonFormat(args)) {
    return JSON.stringify(report) + "\n";
  }
  return formatTextReport(report);
}

function reportWithMetadata(report) {
  return {
    ...report,
    metadata: {
      rulesMeta: rulesMetaForReport(report)
    }
  };
}

function rulesMetaForReport(report) {
  const meta = {};
  for (const diagnostic of report.diagnostics ?? []) {
    if (diagnostic?.ruleId && !meta[diagnostic.ruleId]) {
      meta[diagnostic.ruleId] = ruleMetaForRuleId(diagnostic.ruleId);
    }
  }
  return meta;
}

function ruleMetaForRuleId(ruleId) {
  return {
    docs: {
      url: ruleDocsUrl(ruleId)
    }
  };
}

function ruleDocsUrl(ruleId) {
  if (ruleId.startsWith("@typescript-eslint/")) {
    return `https://typescript-eslint.io/rules/${ruleId.slice("@typescript-eslint/".length)}/`;
  }
  if (ruleId.startsWith("eslint-comments/")) {
    return `https://mysticatea.github.io/eslint-plugin-eslint-comments/rules/${ruleId.slice("eslint-comments/".length)}.html`;
  }
  if (ruleId.startsWith("import/")) {
    return `https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/${ruleId.slice("import/".length)}.md`;
  }
  if (ruleId.startsWith("jsx-a11y/")) {
    return `https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/blob/main/docs/rules/${ruleId.slice("jsx-a11y/".length)}.md`;
  }
  if (ruleId.startsWith("react-hooks/")) {
    return `https://react.dev/reference/eslint-plugin-react-hooks/lints/${ruleId.slice("react-hooks/".length)}`;
  }
  if (ruleId.startsWith("react/")) {
    return `https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/${ruleId.slice("react/".length)}.md`;
  }
  return `https://eslint.org/docs/latest/rules/${ruleId}`;
}

function formatTextReport(report) {
  const diagnostics = report.diagnostics ?? [];
  const lines = diagnostics.map((diagnostic) => {
    const rule = diagnostic.ruleId ? ` [${diagnostic.ruleId}]` : "";
    return `${diagnostic.filePath}:${diagnostic.line}:${diagnostic.column}: ${diagnostic.severity}: ${diagnostic.message}${rule}`;
  });
  lines.push(`${report.files ?? 0} file(s) checked, ${diagnostics.length} diagnostic(s)`);
  return `${lines.join("\n")}\n`;
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
          ["**/*.{less,css,acss}"],
          { valueFlags: STYLELINT_VALUE_FLAGS }
        )
      };
    case "format":
      return {
        bin: "prettier",
        args: withDefaultTargets(
          withDefaultPrettierWrite(translatePassthroughArgs(args)),
          ["**/*.{js,jsx,ts,tsx,less,css,vue}"],
          {
            valueFlags: FORMAT_VALUE_FLAGS
          }
        )
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

function withDefaultPrettierWrite(args) {
  if (hasPrettierMode(args)) {
    return args;
  }
  return ["--write", ...args];
}

function hasPrettierMode(args) {
  return args.some((arg) =>
    arg === "--write" ||
    arg === "--check" ||
    arg === "--list-different" ||
    arg === "--debug-check"
  );
}

function withDefaultTargets(args, defaults, options = {}) {
  if (hasPassthroughTarget(args, options.valueFlags ?? new Set())) {
    return args;
  }
  return [...args, ...defaults];
}

function hasPassthroughTarget(args, valueFlags) {
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--") {
      continue;
    }
    if (valueFlags.has(arg)) {
      index += 1;
      continue;
    }
    if (startsWithValueFlag(arg, valueFlags)) {
      continue;
    }
    if (!arg.startsWith("-")) {
      return true;
    }
  }
  return false;
}

function translatePassthroughArgs(args, options = {}) {
  const passthroughFlags = options.passthroughFlags ?? new Set();
  const dropValueFlags = options.dropValueFlags ?? new Set();
  const translated = [];
  const targets = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--") continue;
    if (FISHLINT_PASSTHROUGH_DROP_FLAGS.has(arg)) continue;
    if (isBooleanValueFlag(arg, FISHLINT_PASSTHROUGH_DROP_FLAGS)) continue;
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

function isBooleanValueFlag(arg, flags) {
  return startsWithValueFlag(arg, flags);
}

function startsWithValueFlag(arg, flags) {
  const separator = arg.indexOf("=");
  if (separator === -1) {
    return false;
  }
  return flags.has(arg.slice(0, separator));
}

function isVersionRequest(args) {
  return args.length === 1 && (args[0] === "--version" || args[0] === "-v");
}

function isHelpRequest(args) {
  return args.length === 1 && (args[0] === "--help" || args[0] === "-h");
}

function printVersion() {
  console.log(`v${version}`);
}

function runNativeHelp() {
  let binary;
  try {
    binary = resolveBinary();
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
  const result = spawnSync(binary, ["--help"], { stdio: "inherit" });
  if (result.error) {
    console.error(`utoo-lint: failed to run native binary: ${result.error.message}`);
    process.exit(1);
  }
  process.exit(result.status ?? 1);
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
    if (arg.startsWith("-E=")) {
      const envKey = arg.slice("-E=".length);
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
