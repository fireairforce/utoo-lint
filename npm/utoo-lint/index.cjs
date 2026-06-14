const { spawnSync } = require("node:child_process");
const { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } = require("node:fs");
const { writeFile: writeFileAsync } = require("node:fs/promises");
const { tmpdir } = require("node:os");
const { extname, isAbsolute, join, resolve: resolvePath } = require("node:path");

const { platformPackageName, resolveBinary } = require("./lib/binary.cjs");

const version = JSON.parse(readFileSync(join(__dirname, "package.json"), "utf8")).version;

const LINTABLE_EXTENSIONS = new Set([".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".mts", ".cts"]);
const FISHLINT_DROP_FLAGS = new Set([
  "--cache",
  "--color",
  "--debug",
  "--disable-legacy",
  "--disable-setup",
  "--no-cache",
  "--no-color",
  "--no-error-on-unmatched-pattern",
  "--no-eslintrc",
  "--no-ignore",
  "--no-inline-config",
  "--no-warn-ignored",
  "--pass-on-no-patterns",
  "--quiet",
  "--report-unused-disable-directives",
  "--stats",
  "--stdin",
  "--verbose",
  "-v"
]);
const FISHLINT_DROP_VALUE_FLAGS = new Set([
  "--cache-location",
  "--cache-strategy",
  "--env",
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
  "--rulesdir",
  "--stdin-filename",
  "-E",
  "-o"
]);

class UtooLint {
  static get version() {
    return version;
  }

  static async outputFixes(results) {
    if (!Array.isArray(results)) {
      throw new Error("'results' must be an array");
    }

    await Promise.all(
      results
        .filter((result) => {
          if (typeof result !== "object" || result === null) {
            throw new Error("'results' must include only objects");
          }
          return typeof result.output === "string" && isAbsolute(result.filePath);
        })
        .map((result) => writeFileAsync(result.filePath, result.output))
    );
  }

  static getErrorResults(results) {
    return getErrorResults(results);
  }

  constructor(options = {}) {
    this.options = { ...options };
  }

  async lintFiles(patterns = ["."], options = {}) {
    const mergedOptions = mergeLintOptions(this.options, options);
    const report = lintFiles(patterns, mergedOptions);
    return maybeFilterQuietResults(reportToESLintResults(report, {
      cwd: mergedOptions.cwd,
      filePaths: reportFilePaths(report, mergedOptions.cwd, explicitLintFilePaths(report.filePaths ?? patterns, mergedOptions.cwd)),
      ruleSeverityForFile: (filePath) => ruleSeverityMapForOptions(mergedOptions, filePath)
    }), mergedOptions);
  }

  async lintText(code, options = {}) {
    if (typeof code !== "string") {
      throw new TypeError("code must be a string");
    }

    const mergedOptions = mergeLintOptions(this.options, options);
    const report = lintText(code, mergedOptions);
    return maybeFilterQuietResults(reportToESLintResults(report, {
      source: code,
      filePath: normalizeESLintFilePath(options.filePath ?? "<text>", mergedOptions.cwd),
      includeEmptyTextResult: report.files !== 0 || (report.diagnostics?.length ?? 0) > 0,
      ruleSeverityForFile: (filePath) => ruleSeverityMapForOptions(mergedOptions, filePath)
    }), mergedOptions);
  }

  async isPathIgnored(filePath) {
    return isPathIgnored(filePath, mergeLintOptions(this.options, {}));
  }

  async calculateConfigForFile(filePath) {
    return calculatedConfig(eslintConstructorOptions(this.options), filePath);
  }

  getRulesMetaForResults(results) {
    if (!Array.isArray(results)) {
      throw new Error("'results' must be an array");
    }
    return rulesMetaForResults(results);
  }

  async loadFormatter(name = "stylish") {
    return {
      format(results) {
        return formatResultsByName(results, name);
      }
    };
  }
}

const ESLint = UtooLint;

class CLIEngine {
  static get version() {
    return version;
  }

  static outputFixes(report) {
    const results = Array.isArray(report) ? report : report?.results;
    if (!Array.isArray(results)) {
      throw new Error("'report' must be an ESLint report or result array");
    }

    for (const result of results) {
      if (typeof result !== "object" || result === null) {
        throw new Error("'report' must include only result objects");
      }
      if (typeof result.output === "string" && isAbsolute(result.filePath)) {
        writeFileSync(result.filePath, result.output);
      }
    }
  }

  static getErrorResults(results) {
    return getErrorResults(results);
  }

  constructor(options = {}) {
    this.options = { ...options };
  }

  executeOnFiles(patterns) {
    const mergedOptions = eslintConstructorOptions(this.options);
    const report = lintFiles(patterns, mergedOptions);
    const results = maybeFilterQuietResults(reportToESLintResults(report, {
      cwd: mergedOptions.cwd,
      filePaths: reportFilePaths(report, mergedOptions.cwd, explicitLintFilePaths(report.filePaths ?? patterns, mergedOptions.cwd)),
      ruleSeverityForFile: (filePath) => ruleSeverityMapForOptions(mergedOptions, filePath)
    }), mergedOptions);
    return resultsToCLIEngineReport(results);
  }

  executeOnText(code, filePathOrOptions = "input.js") {
    const textOptions =
      typeof filePathOrOptions === "object" && filePathOrOptions !== null
        ? filePathOrOptions
        : {};
    const filePath =
      typeof filePathOrOptions === "object" && filePathOrOptions !== null
        ? filePathOrOptions.filePath ?? filePathOrOptions.filename ?? "input.js"
        : filePathOrOptions;
    const mergedOptions = {
      ...eslintConstructorOptions(this.options),
      ...textOptions
    };
    const report = lintText(code, {
      ...mergedOptions,
      filePath
    });
    const results = maybeFilterQuietResults(reportToESLintResults(report, {
      source: code,
      filePath: normalizeESLintFilePath(filePath, mergedOptions.cwd),
      includeEmptyTextResult: report.files !== 0 || (report.diagnostics?.length ?? 0) > 0,
      ruleSeverityForFile: (filePath) => ruleSeverityMapForOptions(mergedOptions, filePath)
    }), mergedOptions);
    return resultsToCLIEngineReport(results);
  }

  getFormatter(name = "stylish") {
    return (results) => {
      return formatResultsByName(results, name);
    };
  }

  isPathIgnored(filePath) {
    return isPathIgnored(filePath, eslintConstructorOptions(this.options));
  }

  getConfigForFile(filePath) {
    return calculatedConfig(eslintConstructorOptions(this.options), filePath);
  }
}

function run(args = [], options = {}) {
  const cliArgs = normalizeStringArray(args, "args");
  const env = options.env ? { ...process.env, ...options.env } : process.env;
  const binary = options.binary ?? resolveBinary({ env });

  return spawnSync(binary, cliArgs, {
    cwd: options.cwd,
    env,
    encoding: options.encoding ?? "utf8",
    input: options.input,
    stdio: options.stdio
  });
}

function runFishlint(args = [], options = {}) {
  const cliArgs = normalizeStringArray(args, "args");
  const env = options.env ? { ...process.env, ...options.env } : { ...process.env };
  if (options.binary) {
    env.UTOO_LINT_BIN = options.binary;
  }

  return spawnSync(process.execPath, [join(__dirname, "bin", "fishlint.js"), ...cliArgs], {
    cwd: options.cwd,
    env,
    encoding: options.encoding ?? "utf8",
    input: options.input,
    stdio: options.stdio
  });
}

function translateFishlintArgs(args = [], options = {}) {
  const values = normalizeStringArray(args, "args");
  const warn = options.warn ?? (() => {});

  if (values.length === 0) {
    return ["--help"];
  }

  const [command, ...rest] = values;
  if (command !== "eslint") {
    throw new Error(`utoo-lint fishlint compatibility only supports the eslint command, received: ${command}`);
  }

  const translated = [];
  const globTargets = [];
  let index = 0;

  while (index < rest.length) {
    const arg = rest[index];
    if (arg === "--") {
      index += 1;
      continue;
    }
    if (FISHLINT_DROP_FLAGS.has(arg)) {
      if (arg === "--no-eslintrc") {
        translated.push("--no-config");
      }
      index += 1;
      continue;
    }
    if (startsWithFlagValue(arg, FISHLINT_DROP_FLAGS)) {
      if (arg.startsWith("--no-eslintrc=") && booleanFlagValue(arg) !== false) {
        translated.push("--no-config");
      }
      index += 1;
      continue;
    }
    if (FISHLINT_DROP_VALUE_FLAGS.has(arg)) {
      const value = rest[index + 1];
      if (!value) {
        throw new Error(`utoo-lint: fishlint ${arg} requires a value`);
      }
      index += 2;
      continue;
    }
    if (startsWithFlagValue(arg, FISHLINT_DROP_VALUE_FLAGS)) {
      index += 1;
      continue;
    }
    if (arg === "--fix") {
      warn("utoo-lint: fishlint --fix is ignored because utoo-lint does not apply fixes yet.");
      index += 1;
      continue;
    }
    if (arg === "--fix-dry-run") {
      warn("utoo-lint: fishlint --fix-dry-run is ignored because utoo-lint does not apply fixes yet.");
      index += 1;
      continue;
    }
    if (arg === "--fix-type") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error("utoo-lint: fishlint --fix-type requires a value");
      }
      warn("utoo-lint: fishlint --fix-type is ignored because utoo-lint does not apply fixes yet.");
      index += 2;
      continue;
    }
    if (arg.startsWith("--fix-type=")) {
      warn("utoo-lint: fishlint --fix-type is ignored because utoo-lint does not apply fixes yet.");
      index += 1;
      continue;
    }
    if (arg === "--format" || arg === "-f") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error(`utoo-lint: fishlint ${arg} requires a formatter name`);
      }
      translated.push(`--format=${translateFishlintFormat(value, warn)}`);
      index += 2;
      continue;
    }
    if (arg.startsWith("--format=")) {
      translated.push(`--format=${translateFishlintFormat(arg.slice("--format=".length), warn)}`);
      index += 1;
      continue;
    }
    if (arg === "--threads") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error("utoo-lint: fishlint --threads requires a number");
      }
      translated.push(`--threads=${value}`);
      index += 2;
      continue;
    }
    if (arg.startsWith("--threads=")) {
      translated.push(arg);
      index += 1;
      continue;
    }
    if (arg === "--rules") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error("utoo-lint: fishlint --rules requires a comma-separated rule list");
      }
      translated.push(`--rules=${value}`);
      index += 2;
      continue;
    }
    if (arg.startsWith("--rules=")) {
      translated.push(arg);
      index += 1;
      continue;
    }
    if (arg === "--config" || arg === "-c") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error(`utoo-lint: fishlint ${arg} requires a path`);
      }
      translated.push(`--config=${value}`);
      index += 2;
      continue;
    }
    if (arg.startsWith("--config=")) {
      translated.push(arg);
      index += 1;
      continue;
    }
    if (arg === "--ext") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error("utoo-lint: fishlint --ext requires an extension list");
      }
      index += 2;
      continue;
    }
    if (arg.startsWith("--ext=")) {
      index += 1;
      continue;
    }
    if (arg === "--glob") {
      const value = rest[index + 1];
      if (!value) {
        throw new Error("utoo-lint: fishlint --glob requires a path");
      }
      globTargets.push(value);
      index += 2;
      continue;
    }
    if (arg.startsWith("--glob=")) {
      globTargets.push(arg.slice("--glob=".length));
      index += 1;
      continue;
    }
    translated.push(arg);
    index += 1;
  }

  if (globTargets.length > 0) {
    translated.push(...globTargets);
  }

  return translated;
}

function translateFishlintFormat(format, warn) {
  if (format === "json" || format === "text") {
    return format;
  }
  if (format === "json-with-metadata") {
    return "json";
  }
  if (format !== "stylish") {
    warn(`utoo-lint: fishlint formatter '${format}' is not implemented; using native text output.`);
  }
  return "text";
}

function startsWithFlagValue(arg, flags) {
  for (const flag of flags) {
    if (arg.startsWith(`${flag}=`)) {
      return true;
    }
  }
  return false;
}

function booleanFlagValue(arg) {
  const value = arg.slice(arg.indexOf("=") + 1).trim().toLowerCase();
  if (value === "false" || value === "0") {
    return false;
  }
  return true;
}

function lintFiles(paths = ["."], options = {}) {
  return withTemporaryConfig(options, (resolvedOptions) => {
    const ignoredDiagnostics = ignoredLintPathDiagnostics(paths, resolvedOptions);
    const lintPaths = filteredLintPaths(paths, resolvedOptions);
    if (lintPaths.length === 0) {
      return { files: 0, filePaths: [], diagnostics: ignoredDiagnostics, exitCode: ignoredDiagnostics.length > 0 ? 1 : 0 };
    }

    const cliArgs = buildLintArgs(lintPaths, resolvedOptions);
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
    report.diagnostics = [
      ...(report.diagnostics ?? []),
      ...ignoredDiagnostics
    ];
    if (!resolvedOptions.deferDiagnosticConfigFiltering) {
      report.filePaths = normalizeReportFilePaths(report.filePaths, resolvedOptions);
      report.diagnostics = normalizeDiagnosticFilePaths(report.diagnostics, resolvedOptions);
      report.diagnostics = normalizeReportDiagnostics(report.diagnostics, resolvedOptions);
    }
    if (stderr) {
      Object.defineProperty(report, "stderr", {
        value: stderr,
        enumerable: false
      });
    }

    return report;
  });
}

function lintText(code, options = {}) {
  if (typeof code !== "string") {
    throw new TypeError("code must be a string");
  }

  const tmp = mkdtempSync(join(tmpdir(), "utoo-lint-"));
  const requestedPath = options.filePath ?? "text.js";
  const extension = extname(requestedPath) || ".js";
  const tempFile = join(tmp, `input${extension}`);
  const discoveredConfig =
    !options.noConfig && !options.config && !options.overrideConfig
      ? configPathForOptions(options)
      : undefined;

  try {
    if (isPathIgnored(requestedPath, options)) {
      const diagnostics = options.warnIgnored === false ? [] : [ignoredFileDiagnostic(normalizeESLintFilePath(requestedPath, options.cwd))];
      return {
        files: 0,
        filePaths: [],
        diagnostics,
        exitCode: diagnostics.length > 0 ? 1 : 0
      };
    }

    writeFileSync(tempFile, code);
    const report = lintFiles([tempFile], {
      ...options,
      cwd: options.cwd,
      config: options.config ?? discoveredConfig,
      noConfig: options.noConfig,
      deferDiagnosticConfigFiltering: true
    });
    report.filePaths = (report.filePaths ?? []).map((filePath) => (filePath === tempFile ? requestedPath : filePath));
    report.diagnostics = report.diagnostics.map((diagnostic) => ({
      ...diagnostic,
      filePath: requestedPath
    }));
    report.diagnostics = normalizeReportDiagnostics(report.diagnostics, options);
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
    if (rules) {
      cliArgs.push(`--rules=${rules}`);
    }
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
    extraArgs: options.extraArgs,
    ignorePath: options.ignorePath,
    ignorePatterns: options.ignorePatterns,
    noIgnore: options.noIgnore ?? options.ignore === false,
    baseConfig: options.baseConfig,
    noConfig: options.noConfig,
    quiet: options.quiet,
    errorOnUnmatchedPattern: options.errorOnUnmatchedPattern,
    warnIgnored: options.warnIgnored
  };

  if (options.useEslintrc === false || options.overrideConfigFile === true) {
    mapped.noConfig = true;
  }
  if (typeof options.overrideConfigFile === "string") {
    mapped.config = options.overrideConfigFile;
  }
  if (options.overrideConfig) {
    mapped.overrideConfig = Array.isArray(options.overrideConfig) ? options.overrideConfig : { ...options.overrideConfig };
    if (!Array.isArray(mapped.overrideConfig) && !mapped.overrideConfig.rules && options.baseConfig?.rules) {
      mapped.overrideConfig.rules = options.baseConfig.rules;
    }
  } else if (options.baseConfig?.rules) {
    mapped.overrideConfig = { rules: options.baseConfig.rules };
  }
  return mapped;
}

function calculatedConfig(options = {}, filePath) {
  return {
    rules: {
      ...rulesFromConfig(options.baseConfig, filePath, options.cwd),
      ...rulesFromFileConfig(options, filePath),
      ...rulesFromConfig(options.overrideConfig, filePath, options.cwd)
    }
  };
}

function rulesFromConfig(config, filePath, cwd) {
  if (!config) {
    return {};
  }
  if (Array.isArray(config)) {
    return config.reduce((rules, entry) => ({
      ...rules,
      ...rulesFromConfig(entry, filePath, cwd)
    }), {});
  }
  if (!configAppliesToFile(config, filePath, cwd)) {
    return {};
  }
  return config.rules && typeof config.rules === "object" ? config.rules : {};
}

function rulesFromFileConfig(options, filePath) {
  if (options.noConfig) {
    return {};
  }

  const configPath = configPathForOptions(options);
  if (!configPath) {
    return {};
  }

  const config = readJsonConfig(configPath);
  return rulesFromConfig(config, filePath, options.cwd);
}

function configAppliesToFile(config, filePath, cwd) {
  if (!filePath) {
    return true;
  }

  const normalized = normalizeIgnoredPath(filePath, cwd ?? process.cwd());
  const files = normalizeConfigPatterns(config.files);
  if (files.length > 0 && !files.some((pattern) => matchesIgnorePattern(normalized, normalizeIgnoredPattern(pattern)))) {
    return false;
  }

  const ignores = normalizeIgnorePatterns(config.ignores);
  return !pathIgnoredByPatterns(normalized, ignores);
}

function normalizeConfigPatterns(patterns) {
  if (!patterns) {
    return [];
  }
  const values = Array.isArray(patterns) ? patterns : [patterns];
  return values.flatMap((value) => {
    if (typeof value === "string") {
      return [value];
    }
    return [];
  });
}

function configPathForOptions(options) {
  if (options.config) {
    return resolvePath(options.cwd ?? process.cwd(), options.config);
  }

  const cwd = options.cwd ?? process.cwd();
  for (const candidate of ["utoo.json", "utoo-lint.json"]) {
    const path = resolvePath(cwd, candidate);
    if (existsSync(path)) {
      return path;
    }
  }
  return undefined;
}

function readJsonConfig(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`utoo-lint unable to read config ${path}: ${error.message}`);
  }
}

function withTemporaryConfig(options, callback) {
  const inlineRules = {
    ...rulesFromConfig(options.baseConfig),
    ...rulesFromConfig(options.overrideConfig)
  };
  if (Object.keys(inlineRules).length === 0) {
    return callback(options);
  }

  const rules = calculatedConfig(options).rules;
  const enabledRules = enabledRuleNamesFromConfigs(options.baseConfig, options.overrideConfig);
  if (!hasRuleOptions(rules)) {
    return callback({
      ...options,
      noConfig: options.noConfig ?? true,
      rules: options.rules ?? enabledRules
    });
  }

  const tmp = mkdtempSync(join(tmpdir(), "utoo-lint-config-"));
  const configPath = join(tmp, "utoo.json");
  try {
    writeFileSync(configPath, JSON.stringify({ rules }));
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
    .filter(([, value]) => ruleConfigSeverity(value) > 0)
    .map(([rule]) => rule);
}

function enabledRuleNamesFromConfigs(...configs) {
  const rules = new Set();
  for (const config of configs) {
    for (const rule of enabledRuleNamesFromConfig(config)) {
      rules.add(rule);
    }
  }
  return [...rules];
}

function enabledRuleNamesFromConfig(config) {
  if (!config) {
    return [];
  }
  if (Array.isArray(config)) {
    return config.flatMap((entry) => enabledRuleNamesFromConfig(entry));
  }
  return enabledRuleNames(rulesFromConfig(config));
}

function hasRuleOptions(rules) {
  return Object.values(rules).some((value) => Array.isArray(value) && value.length > 1);
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
    const filePath = textOptions.filePath ?? normalizeESLintFilePath(diagnostic.filePath, textOptions.cwd);
    if (!byFile.has(filePath)) {
      byFile.set(filePath, emptyESLintResult(filePath, textOptions.source));
    }
    const ruleSeverities = textOptions.ruleSeverityForFile?.(filePath) ?? textOptions.ruleSeverities;
    if (diagnostic.ruleId && ruleSeverities?.get(diagnostic.ruleId) === 0) {
      continue;
    }
    byFile.get(filePath).messages.push(diagnosticToESLintMessage(diagnostic, ruleSeverities));
  }

  if (textOptions.filePath && textOptions.includeEmptyTextResult !== false && !byFile.has(textOptions.filePath)) {
    byFile.set(textOptions.filePath, emptyESLintResult(textOptions.filePath, textOptions.source));
  }
  for (const filePath of textOptions.filePaths ?? []) {
    if (!byFile.has(filePath)) {
      byFile.set(filePath, emptyESLintResult(filePath));
    }
  }

  for (const result of byFile.values()) {
    finalizeESLintResult(result);
  }

  return [...byFile.values()];
}

function normalizeReportDiagnostics(diagnostics, options = {}) {
  return (diagnostics ?? []).flatMap((diagnostic) => {
    if (!diagnostic?.ruleId) {
      return [diagnostic];
    }

    const filePath = normalizeESLintFilePath(diagnostic.filePath, options.cwd);
    const severity = ruleSeverityMapForOptions(options, filePath)?.get(diagnostic.ruleId);
    if (severity === 0) {
      return [];
    }
    if (severity === 1 || severity === 2) {
      return [{ ...diagnostic, severity: severity === 2 ? "error" : "warning" }];
    }
    return [diagnostic];
  });
}

function normalizeReportFilePaths(filePaths, options = {}) {
  return (filePaths ?? []).map((filePath) => normalizeESLintFilePath(filePath, options.cwd));
}

function normalizeDiagnosticFilePaths(diagnostics, options = {}) {
  return (diagnostics ?? []).map((diagnostic) => ({
    ...diagnostic,
    filePath: normalizeESLintFilePath(diagnostic.filePath, options.cwd)
  }));
}

function normalizeESLintFilePath(filePath, cwd) {
  if (filePath === "<text>") return filePath;
  if (isAbsolute(filePath)) return filePath;
  return resolvePath(cwd ?? process.cwd(), filePath);
}

function reportFilePaths(report, cwd, fallbackFilePaths = []) {
  const filePaths = new Set();
  if (Array.isArray(report.filePaths)) {
    for (const filePath of report.filePaths) {
      if (typeof filePath === "string") {
        filePaths.add(normalizeESLintFilePath(filePath, cwd));
      }
    }
  }
  for (const filePath of fallbackFilePaths) {
    filePaths.add(filePath);
  }
  return [...filePaths];
}

function explicitLintFilePaths(patterns, cwd) {
  const files = [];
  for (const pattern of normalizeStringArray(Array.isArray(patterns) ? patterns : [patterns], "patterns")) {
    if (hasGlobMagic(pattern)) continue;

    const filePath = normalizeESLintFilePath(pattern, cwd);
    if (!isLintableFilePath(filePath)) continue;

    try {
      if (statSync(filePath).isFile()) {
        files.push(filePath);
      }
    } catch {
      // Let the native binary report missing paths. This helper only fills in
      // empty ESLint results for files that were checked successfully.
    }
  }
  return files;
}

function hasGlobMagic(pattern) {
  return /[*?[\]{}()!+@]/.test(pattern);
}

function isLintableFilePath(filePath) {
  return LINTABLE_EXTENSIONS.has(extname(filePath));
}

function filteredLintPaths(paths, options = {}) {
  const values = normalizeStringArray(Array.isArray(paths) ? paths : [paths], "paths");
  const cwd = options.cwd ?? process.cwd();
  const patterns = options.noIgnore ? [] : ignorePatternsForOptions(options, cwd);
  if (patterns.length === 0 && options.errorOnUnmatchedPattern !== false && !values.some(hasGlobMagic)) {
    return values;
  }
  const excludedPatterns = negatedLintPatterns(values);

  const filtered = new Set();
  for (const target of values) {
    if (isNegatedLintPattern(target)) {
      continue;
    }
    if (hasGlobMagic(target)) {
      const expanded = expandGlobTarget(target, cwd, patterns);
      if (expanded.length > 0) {
        for (const filePath of expanded) {
          filtered.add(filePath);
        }
        continue;
      }
      if (options.errorOnUnmatchedPattern === false) {
        continue;
      }
      if (!pathIgnoredByPatterns(normalizeIgnoredPath(target, cwd), patterns)) {
        filtered.add(target);
      }
      continue;
    }

    const expanded = expandLintTarget(target, cwd, patterns);
    if (expanded == null) {
      if (options.errorOnUnmatchedPattern === false) {
        continue;
      }
      if (!pathIgnoredByPatterns(normalizeIgnoredPath(target, cwd), patterns)) {
        filtered.add(target);
      }
      continue;
    }
    for (const filePath of expanded) {
      filtered.add(filePath);
    }
  }
  return [...filtered].filter((filePath) => !pathIgnoredByPatterns(normalizeIgnoredPath(filePath, cwd), excludedPatterns));
}

function negatedLintPatterns(values) {
  return values
    .filter(isNegatedLintPattern)
    .map((value) => value.slice(1))
    .filter((value) => value.length > 0);
}

function isNegatedLintPattern(value) {
  return value.startsWith("!") && value.length > 1;
}

function expandGlobTarget(target, cwd, patterns) {
  const base = globBaseDirectory(target);
  const absoluteBase = normalizeESLintFilePath(base, cwd);
  let stat;
  try {
    stat = statSync(absoluteBase);
  } catch {
    return [];
  }
  if (!stat.isDirectory()) {
    return [];
  }

  const expression = new RegExp(`^${globPatternRegExpSource(normalizePath(target))}$`);
  const files = [];
  collectGlobFiles(base, cwd, patterns, expression, files);
  return files;
}

function globBaseDirectory(pattern) {
  const segments = normalizePath(pattern).split("/");
  const baseSegments = [];
  for (const segment of segments) {
    if (hasGlobMagic(segment)) {
      break;
    }
    baseSegments.push(segment);
  }
  return baseSegments.length > 0 ? baseSegments.join("/") : ".";
}

function collectGlobFiles(target, cwd, patterns, expression, files) {
  const absolute = normalizeESLintFilePath(target, cwd);
  for (const entry of readdirSync(absolute, { withFileTypes: true })) {
    if (shouldSkipDirectoryEntry(entry.name)) {
      continue;
    }

    const child = join(target, entry.name);
    if (entry.isDirectory()) {
      if (!pathIgnoredByPatterns(normalizeIgnoredPath(child, cwd), patterns)) {
        collectGlobFiles(child, cwd, patterns, expression, files);
      }
      continue;
    }
    if (
      entry.isFile() &&
      isLintableFilePath(child) &&
      expression.test(normalizePath(child)) &&
      !pathIgnoredByPatterns(normalizeIgnoredPath(child, cwd), patterns)
    ) {
      files.push(child);
    }
  }
}

function ignoredLintPathDiagnostics(paths, options = {}) {
  if (options.noIgnore || options.warnIgnored === false) {
    return [];
  }

  const cwd = options.cwd ?? process.cwd();
  const patterns = ignorePatternsForOptions(options, cwd);
  if (patterns.length === 0) {
    return [];
  }

  const diagnostics = [];
  for (const target of normalizeStringArray(Array.isArray(paths) ? paths : [paths], "paths")) {
    if (hasGlobMagic(target)) continue;

    const filePath = normalizeESLintFilePath(target, cwd);
    if (!isLintableFilePath(filePath)) continue;

    try {
      if (!statSync(filePath).isFile()) continue;
    } catch {
      continue;
    }

    if (pathIgnoredByPatterns(normalizeIgnoredPath(target, cwd), patterns)) {
      diagnostics.push(ignoredFileDiagnostic(filePath));
    }
  }
  return diagnostics;
}

function ignoredFileDiagnostic(filePath) {
  return {
    filePath,
    line: 0,
    column: 0,
    severity: "warning",
    message: "File ignored because of a matching ignore pattern. Use noIgnore to override.",
    ruleId: null
  };
}

function expandLintTarget(target, cwd, patterns) {
  const absolute = normalizeESLintFilePath(target, cwd);
  let stat;
  try {
    stat = statSync(absolute);
  } catch {
    return null;
  }

  if (stat.isFile()) {
    return isLintableFilePath(target) && !pathIgnoredByPatterns(normalizeIgnoredPath(target, cwd), patterns) ? [target] : [];
  }
  if (!stat.isDirectory() || pathIgnoredByPatterns(normalizeIgnoredPath(target, cwd), patterns)) {
    return [];
  }

  const files = [];
  collectLintableFiles(target, cwd, patterns, files);
  return files;
}

function collectLintableFiles(target, cwd, patterns, files) {
  const absolute = normalizeESLintFilePath(target, cwd);
  for (const entry of readdirSync(absolute, { withFileTypes: true })) {
    if (shouldSkipDirectoryEntry(entry.name)) {
      continue;
    }

    const child = join(target, entry.name);
    if (entry.isDirectory()) {
      if (!pathIgnoredByPatterns(normalizeIgnoredPath(child, cwd), patterns)) {
        collectLintableFiles(child, cwd, patterns, files);
      }
      continue;
    }
    if (entry.isFile() && isLintableFilePath(child) && !pathIgnoredByPatterns(normalizeIgnoredPath(child, cwd), patterns)) {
      files.push(child);
    }
  }
}

function shouldSkipDirectoryEntry(name) {
  return name === ".git" || name === ".zig-cache" || name === "node_modules" || name === "vendor" || name === "zig-out";
}

function isPathIgnored(filePath, options = {}) {
  if (typeof filePath !== "string") {
    throw new TypeError("filePath must be a string");
  }
  if (options.noIgnore) {
    return false;
  }

  const cwd = options.cwd ?? process.cwd();
  const normalized = normalizeIgnoredPath(filePath, cwd);
  const patterns = ignorePatternsForOptions(options, cwd);
  return pathIgnoredByPatterns(normalized, patterns);
}

function ignorePatternsForOptions(options, cwd) {
  const patterns = [];
  for (const pattern of normalizeIgnorePatterns(options.ignorePatterns)) {
    patterns.push(pattern);
  }
  patterns.push(...ignorePatternsFromConfig(options.baseConfig));

  const ignorePath = options.ignorePath ?? ".eslintignore";
  if (ignorePath) {
    patterns.push(...readIgnoreFile(resolvePath(cwd, ignorePath)));
  }
  patterns.push(...ignorePatternsFromFileConfig(options));
  patterns.push(...ignorePatternsFromConfig(options.overrideConfig));
  return patterns;
}

function ignorePatternsFromFileConfig(options) {
  if (options.noConfig) {
    return [];
  }

  const configPath = configPathForOptions(options);
  if (!configPath) {
    return [];
  }

  return ignorePatternsFromConfig(readJsonConfig(configPath));
}

function ignorePatternsFromConfig(config) {
  if (!config) {
    return [];
  }
  if (Array.isArray(config)) {
    return config.flatMap((entry) => ignorePatternsFromConfig(entry));
  }

  return [
    ...normalizeIgnorePatterns(config.ignorePatterns),
    ...normalizeIgnorePatterns(config.ignores)
  ];
}

function normalizeIgnorePatterns(patterns) {
  if (!patterns) {
    return [];
  }
  const values = Array.isArray(patterns) ? patterns : [patterns];
  for (const value of values) {
    if (typeof value !== "string") {
      throw new TypeError("ignorePatterns must be a string or an array of strings");
    }
  }
  return values;
}

function readIgnoreFile(path) {
  if (!existsSync(path)) {
    return [];
  }

  return readFileSync(path, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}

function normalizeIgnoredPath(filePath, cwd) {
  const root = resolvePath(cwd);
  const absolute = normalizeESLintFilePath(filePath, root);
  const relative =
    absolute === root || absolute.startsWith(`${root}/`) || absolute.startsWith(`${root}\\`)
      ? absolute.slice(root.length).replace(/^[/\\]/, "")
      : absolute;
  return normalizePath(relative);
}

function normalizeIgnoredPattern(pattern) {
  return normalizePath(pattern.replace(/^!/, "").replace(/^\//, ""));
}

function pathIgnoredByPatterns(target, patterns) {
  let ignored = false;
  for (const pattern of patterns) {
    const negated = pattern.startsWith("!");
    if (matchesIgnorePattern(target, normalizeIgnoredPattern(pattern))) {
      ignored = !negated;
    }
  }
  return ignored;
}

function matchesIgnorePattern(target, pattern) {
  if (pattern.endsWith("/**")) {
    const prefix = pattern.slice(0, -3);
    return target === prefix || target.startsWith(`${prefix}/`) || target.includes(`/${prefix}/`);
  }
  if (pattern.startsWith("**/")) {
    const suffix = pattern.slice(3);
    return target.endsWith(suffix) || target.includes(`/${suffix}`);
  }
  if (!pattern.includes("*")) {
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

function getErrorResults(results) {
  if (!Array.isArray(results)) {
    throw new Error("'results' must be an array");
  }

  const filtered = [];
  for (const result of results) {
    const messages = (result.messages ?? []).filter((message) => message.severity === 2);
    if (messages.length === 0) continue;
    filtered.push({
      ...result,
      messages,
      suppressedMessages: (result.suppressedMessages ?? []).filter((message) => message.severity === 2),
      errorCount: messages.length,
      warningCount: 0,
      fixableWarningCount: 0
    });
  }
  return filtered;
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

function resultsToCLIEngineReport(results) {
  const report = {
    results,
    errorCount: 0,
    fatalErrorCount: 0,
    warningCount: 0,
    fixableErrorCount: 0,
    fixableWarningCount: 0,
    usedDeprecatedRules: []
  };

  for (const result of results) {
    report.errorCount += result.errorCount ?? 0;
    report.fatalErrorCount += result.fatalErrorCount ?? 0;
    report.warningCount += result.warningCount ?? 0;
    report.fixableErrorCount += result.fixableErrorCount ?? 0;
    report.fixableWarningCount += result.fixableWarningCount ?? 0;
  }

  return report;
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

function diagnosticToESLintMessage(diagnostic, ruleSeverities) {
  return {
    ruleId: diagnostic.ruleId,
    severity: ruleSeverities?.get(diagnostic.ruleId) ?? (diagnostic.severity === "error" ? 2 : 1),
    message: diagnostic.message,
    line: diagnostic.line,
    column: diagnostic.column,
    nodeType: null
  };
}

function finalizeESLintResult(result) {
  result.errorCount = 0;
  result.warningCount = 0;
  for (const message of result.messages) {
    if (message.severity === 2) {
      result.errorCount += 1;
    } else {
      result.warningCount += 1;
    }
  }
}

function maybeFilterQuietResults(results, options = {}) {
  if (!options.quiet) {
    return results;
  }

  for (const result of results) {
    result.messages = (result.messages ?? []).filter((message) => message.severity === 2);
    result.suppressedMessages = (result.suppressedMessages ?? []).filter((message) => message.severity === 2);
    result.fixableWarningCount = 0;
    finalizeESLintResult(result);
  }
  return results;
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

function formatResultsByName(results, name = "stylish") {
  if (name === "json") {
    return JSON.stringify(results);
  }
  if (name === "json-with-metadata") {
    return JSON.stringify({
      results,
      metadata: {
        rulesMeta: rulesMetaForResults(results)
      }
    });
  }
  if (name === "compact") {
    return formatCompactResults(results);
  }
  if (name === "unix") {
    return formatUnixResults(results);
  }
  return formatESLintResults(results);
}

function formatCompactResults(results) {
  const lines = [];
  for (const result of results) {
    for (const message of result.messages ?? []) {
      lines.push(`${result.filePath}: line ${message.line}, col ${message.column}, ${message.severity === 2 ? "Error" : "Warning"} - ${message.message} (${message.ruleId ?? ""})`);
    }
  }
  return lines.join("\n");
}

function formatUnixResults(results) {
  const lines = [];
  for (const result of results) {
    for (const message of result.messages ?? []) {
      lines.push(`${result.filePath}:${message.line}:${message.column}: ${message.message} [${message.severity === 2 ? "Error" : "Warning"}/${message.ruleId ?? ""}]`);
    }
  }
  return lines.join("\n");
}

function rulesMetaForResults(results) {
  if (!Array.isArray(results)) {
    throw new Error("'results' must be an array");
  }

  const meta = {};
  for (const result of results) {
    for (const message of [...(result.messages ?? []), ...(result.suppressedMessages ?? [])]) {
      if (message.ruleId) {
        meta[message.ruleId] = ruleMetaForRuleId(message.ruleId);
      }
    }
  }
  return meta;
}

function ruleSeverityMap(rules) {
  if (!rules) return undefined;

  const severities = new Map();
  for (const [rule, config] of Object.entries(rules)) {
    const severity = ruleConfigSeverity(config);
    severities.set(rule, severity);
  }
  return severities;
}

function ruleSeverityMapForOptions(options, filePath) {
  return ruleSeverityMap(calculatedConfig(options, filePath).rules);
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

module.exports = {
  CLIEngine,
  ESLint,
  UtooLint,
  default: UtooLint,
  lintFiles,
  lintText,
  platformPackageName,
  resolveBinary,
  run,
  runFishlint,
  translateFishlintArgs,
  version
};
