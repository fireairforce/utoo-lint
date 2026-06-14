import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, join } from "node:path";

import { resolveBinary } from "./lib/binary.js";

export { platformPackageName, resolveBinary } from "./lib/binary.js";

export class UtooLint {
  constructor(options = {}) {
    this.options = { ...options };
  }

  async lintFiles(patterns = ["."], options = {}) {
    const report = lintFiles(patterns, mergeLintOptions(this.options, options));
    return reportToESLintResults(report);
  }

  async lintText(code, options = {}) {
    if (typeof code !== "string") {
      throw new TypeError("code must be a string");
    }

    const report = lintText(code, mergeLintOptions(this.options, options));
    return reportToESLintResults(report, {
      source: code,
      filePath: options.filePath ?? "<text>"
    });
  }

  async isPathIgnored() {
    return false;
  }

  async calculateConfigForFile() {
    return {
      rules: this.options.overrideConfig?.rules ?? {}
    };
  }

  async loadFormatter(name = "stylish") {
    return {
      format(results) {
        if (name === "json") {
          return JSON.stringify(results);
        }
        return formatESLintResults(results);
      }
    };
  }
}

export { UtooLint as ESLint };

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
  return withTemporaryConfig(options, (resolvedOptions) => {
    const cliArgs = buildLintArgs(paths, resolvedOptions);
    const result = run(cliArgs, { ...resolvedOptions, stdio: undefined, encoding: "utf8" });

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
  });
}

export function lintText(code, options = {}) {
  if (typeof code !== "string") {
    throw new TypeError("code must be a string");
  }

  const tmp = mkdtempSync(join(tmpdir(), "utoo-lint-"));
  const requestedPath = options.filePath ?? "text.js";
  const extension = extname(requestedPath) || ".js";
  const tempFile = join(tmp, `input${extension}`);

  try {
    writeFileSync(tempFile, code);
    const report = lintFiles([tempFile], {
      ...options,
      cwd: options.cwd,
      noConfig: options.noConfig ?? !(options.config || options.overrideConfig)
    });
    report.diagnostics = report.diagnostics.map((diagnostic) => ({
      ...diagnostic,
      filePath: requestedPath
    }));
    return report;
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
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

function mergeLintOptions(base, override) {
  return {
    ...eslintConstructorOptions(base),
    ...override
  };
}

function eslintConstructorOptions(options) {
  const mapped = {
    cwd: options.cwd,
    threads: options.threads,
    binary: options.binary,
    env: options.env,
    extraArgs: options.extraArgs
  };

  if (options.useEslintrc === false || options.overrideConfigFile === true) {
    mapped.noConfig = true;
  }
  if (typeof options.overrideConfigFile === "string") {
    mapped.config = options.overrideConfigFile;
  }
  if (options.overrideConfig?.rules) {
    mapped.overrideConfig = { rules: options.overrideConfig.rules };
  }
  return mapped;
}

function withTemporaryConfig(options, callback) {
  if (!options.overrideConfig?.rules) {
    return callback(options);
  }

  const enabledRules = enabledRuleNames(options.overrideConfig.rules);
  if (!hasRuleOptions(options.overrideConfig.rules)) {
    return callback({
      ...options,
      noConfig: options.noConfig ?? true,
      rules: options.rules ?? enabledRules
    });
  }

  const tmp = mkdtempSync(join(tmpdir(), "utoo-lint-config-"));
  const configPath = join(tmp, "utoo.json");
  try {
    writeFileSync(configPath, JSON.stringify({ rules: options.overrideConfig.rules }));
    return callback({
      ...options,
      config: options.config ?? configPath,
      noConfig: false
    });
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function enabledRuleNames(rules) {
  return Object.entries(rules)
    .filter(([, value]) => ruleConfigIsEnabled(value))
    .map(([rule]) => rule);
}

function hasRuleOptions(rules) {
  return Object.values(rules).some((value) => Array.isArray(value) && value.length > 1);
}

function ruleConfigIsEnabled(value) {
  const severity = Array.isArray(value) ? value[0] : value;
  if (severity === false || severity === 0) return false;
  if (typeof severity === "string") {
    return !["off", "0"].includes(severity.toLowerCase());
  }
  return true;
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

function reportToESLintResults(report, textOptions = {}) {
  const byFile = new Map();

  for (const diagnostic of report.diagnostics ?? []) {
    const filePath = textOptions.filePath ?? diagnostic.filePath;
    if (!byFile.has(filePath)) {
      byFile.set(filePath, emptyESLintResult(filePath, textOptions.source));
    }
    byFile.get(filePath).messages.push(diagnosticToESLintMessage(diagnostic));
  }

  if (textOptions.filePath && !byFile.has(textOptions.filePath)) {
    byFile.set(textOptions.filePath, emptyESLintResult(textOptions.filePath, textOptions.source));
  }

  for (const result of byFile.values()) {
    finalizeESLintResult(result);
  }

  return [...byFile.values()];
}

function emptyESLintResult(filePath, source) {
  const result = {
    filePath,
    messages: [],
    suppressedMessages: [],
    errorCount: 0,
    fatalErrorCount: 0,
    warningCount: 0,
    fixableErrorCount: 0,
    fixableWarningCount: 0,
    usedDeprecatedRules: []
  };
  if (source != null) {
    result.source = source;
  }
  return result;
}

function diagnosticToESLintMessage(diagnostic) {
  return {
    ruleId: diagnostic.ruleId,
    severity: diagnostic.severity === "error" ? 2 : 1,
    message: diagnostic.message,
    line: diagnostic.line,
    column: diagnostic.column,
    nodeType: null
  };
}

function finalizeESLintResult(result) {
  for (const message of result.messages) {
    if (message.severity === 2) {
      result.errorCount += 1;
    } else {
      result.warningCount += 1;
    }
  }
}

function formatESLintResults(results) {
  const lines = [];
  let errorCount = 0;
  let warningCount = 0;

  for (const result of results) {
    if (result.messages.length === 0) continue;
    lines.push(result.filePath);
    for (const message of result.messages) {
      const severity = message.severity === 2 ? "error" : "warning";
      lines.push(`  ${message.line}:${message.column}  ${severity}  ${message.message}  ${message.ruleId}`);
    }
    errorCount += result.errorCount;
    warningCount += result.warningCount;
  }

  if (errorCount || warningCount) {
    lines.push("");
    lines.push(`x ${errorCount + warningCount} problem${errorCount + warningCount === 1 ? "" : "s"} (${errorCount} error${errorCount === 1 ? "" : "s"}, ${warningCount} warning${warningCount === 1 ? "" : "s"})`);
  }

  return lines.join("\n");
}
