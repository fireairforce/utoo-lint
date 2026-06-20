const { spawnSync } = require("node:child_process");
const { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } = require("node:fs");
const { writeFile: writeFileAsync } = require("node:fs/promises");
const { tmpdir } = require("node:os");
const { dirname, extname, isAbsolute, join, resolve: resolvePath } = require("node:path");

const { platformPackageName, resolveBinary } = require("./lib/binary.cjs");

const version = JSON.parse(readFileSync(join(__dirname, "package.json"), "utf8")).version;

const LINTABLE_EXTENSIONS = new Set([".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".mts", ".cts"]);
const MAX_AUTOFIX_PASSES = 10;
const JS_KEYWORDS = new Set([
  "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete",
  "do", "else", "export", "extends", "finally", "for", "function", "if", "import", "in",
  "instanceof", "let", "new", "return", "super", "switch", "this", "throw", "try", "typeof",
  "var", "void", "while", "with", "yield"
]);
const AST_TRAVERSAL_SKIP_KEYS = new Set([
  "type", "parent", "loc", "range", "tokens", "comments", "leadingComments", "trailingComments",
  "innerComments", "raw", "value", "name", "regex", "bigint", "errors"
]);
const RULE_TESTER_INITIAL_CONFIG = { rules: {} };
let ruleTesterDefaultConfig = { rules: {} };
let ruleTesterDescribe = null;
let ruleTesterIt = null;
let ruleTesterItOnly = null;
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
const CONFIG_FILENAMES = ["utoo.json", "utoo-lint.json"];
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
const BUILTIN_RULE_IDS = [
  "accessor-pairs",
  "array-callback-return",
  "arrow-body-style",
  "block-scoped-var",
  "camelcase",
  "capitalized-comments",
  "complexity",
  "consistent-return",
  "consistent-this",
  "constructor-super",
  "curly",
  "default-case",
  "default-case-last",
  "default-param-last",
  "dot-notation",
  "eol-last",
  "eqeqeq",
  "for-direction",
  "func-name-matching",
  "func-names",
  "func-style",
  "getter-return",
  "grouped-accessor-pairs",
  "guard-for-in",
  "id-denylist",
  "id-length",
  "id-match",
  "init-declarations",
  "linebreak-style",
  "logical-assignment-operators",
  "max-classes-per-file",
  "max-depth",
  "max-lines",
  "max-lines-per-function",
  "max-nested-callbacks",
  "max-params",
  "max-statements",
  "new-cap",
  "new-parens",
  "no-alert",
  "no-array-constructor",
  "no-async-promise-executor",
  "no-await-in-loop",
  "no-bitwise",
  "no-buffer-constructor",
  "no-caller",
  "no-case-declarations",
  "no-class-assign",
  "no-confusing-arrow",
  "no-comma-operator",
  "no-compare-neg-zero",
  "no-cond-assign",
  "no-console",
  "no-const-assign",
  "no-constant-binary-expression",
  "no-constant-condition",
  "no-constructor-return",
  "no-continue",
  "no-control-regex",
  "no-debugger",
  "no-delete-var",
  "no-div-regex",
  "no-dupe-args",
  "no-dupe-class-members",
  "no-dupe-else-if",
  "no-dupe-keys",
  "no-duplicate-case",
  "no-duplicate-imports",
  "no-else-return",
  "no-empty",
  "no-empty-block-statements",
  "no-empty-character-class",
  "no-empty-function",
  "no-empty-pattern",
  "no-empty-static-block",
  "no-eq-null",
  "no-eval",
  "no-ex-assign",
  "no-extend-native",
  "no-extra-bind",
  "no-extra-boolean-cast",
  "no-extra-label",
  "no-extra-semi",
  "no-fallthrough",
  "no-floating-decimal",
  "no-for-in",
  "no-func-assign",
  "no-global-assign",
  "no-global-is-finite",
  "no-global-is-nan",
  "no-implicit-coercion",
  "no-implicit-globals",
  "no-implied-eval",
  "no-import-assign",
  "no-inline-comments",
  "no-inner-declarations",
  "no-invalid-regexp",
  "no-irregular-whitespace",
  "no-iterator",
  "no-label-var",
  "no-labels",
  "no-lone-blocks",
  "no-lonely-if",
  "no-loop-func",
  "no-loss-of-precision",
  "no-mixed-spaces-and-tabs",
  "no-misleading-character-class",
  "no-multi-assign",
  "no-multi-spaces",
  "no-multi-str",
  "no-multiple-empty-lines",
  "no-negated-condition",
  "no-nested-ternary",
  "no-new",
  "no-new-func",
  "no-new-native-nonconstructor",
  "no-new-object",
  "no-new-require",
  "no-new-symbol",
  "no-new-wrappers",
  "no-nonoctal-decimal-escape",
  "no-obj-calls",
  "no-object-constructor",
  "no-octal",
  "no-octal-escape",
  "no-param-reassign",
  "no-path-concat",
  "no-plusplus",
  "no-process-env",
  "no-process-exit",
  "no-promise-executor-return",
  "no-proto",
  "no-prototype-builtins",
  "no-redeclare",
  "no-restricted-exports",
  "no-restricted-globals",
  "no-restricted-imports",
  "no-restricted-modules",
  "no-restricted-properties",
  "no-restricted-syntax",
  "no-regex-spaces",
  "no-return-assign",
  "no-return-await",
  "no-script-url",
  "no-self-assign",
  "no-self-compare",
  "no-sequences",
  "no-setter-return",
  "no-shadow",
  "no-shadow-restricted-names",
  "no-sparse-arrays",
  "no-tabs",
  "no-template-curly-in-string",
  "no-ternary",
  "no-this-before-super",
  "no-throw-literal",
  "no-trailing-spaces",
  "no-undef",
  "no-undef-init",
  "no-unassigned-vars",
  "no-underscore-dangle",
  "no-undefined",
  "no-unneeded-ternary",
  "no-unreachable",
  "no-unreachable-loop",
  "no-unsafe-finally",
  "no-unsafe-negation",
  "no-unsafe-optional-chaining",
  "no-unused-expressions",
  "no-unused-labels",
  "no-unused-private-class-members",
  "no-unused-vars",
  "no-use-before-define",
  "no-useless-backreference",
  "no-useless-call",
  "no-useless-catch",
  "no-useless-computed-key",
  "no-useless-concat",
  "no-useless-constructor",
  "no-useless-escape",
  "no-useless-rename",
  "no-useless-return",
  "no-var",
  "no-void",
  "no-warning-comments",
  "no-with",
  "object-shorthand",
  "one-var",
  "operator-assignment",
  "prefer-arrow-callback",
  "prefer-const",
  "prefer-destructuring",
  "prefer-exponentiation-operator",
  "prefer-named-capture-group",
  "prefer-numeric-literals",
  "prefer-object-has-own",
  "prefer-object-spread",
  "prefer-promise-reject-errors",
  "preserve-caught-error",
  "prefer-regex-literals",
  "prefer-rest-params",
  "prefer-spread",
  "prefer-template",
  "radix",
  "require-await",
  "require-atomic-updates",
  "require-unicode-regexp",
  "require-yield",
  "sort-imports",
  "sort-keys",
  "sort-vars",
  "spaced-comment",
  "strict",
  "symbol-description",
  "unicode-bom",
  "use-isnan",
  "valid-typeof",
  "vars-on-top",
  "wrap-iife",
  "yoda",
  "eslint-comments/no-restricted-disable",
  "import/default",
  "import/export",
  "import/first",
  "import/named",
  "import/namespace",
  "import/newline-after-import",
  "import/no-amd",
  "import/no-cycle",
  "import/no-duplicates",
  "import/no-named-as-default",
  "import/no-named-as-default-member",
  "import/no-unresolved",
  "import/no-self-import",
  "jsx-a11y/alt-text",
  "jsx-a11y/anchor-has-content",
  "jsx-a11y/aria-props",
  "jsx-a11y/aria-proptypes",
  "jsx-a11y/aria-role",
  "jsx-a11y/aria-unsupported-elements",
  "jsx-a11y/iframe-has-title",
  "jsx-a11y/img-redundant-alt",
  "jsx-a11y/no-access-key",
  "jsx-a11y/no-distracting-elements",
  "jsx-a11y/role-has-required-aria-props",
  "jsx-a11y/role-supports-aria-props",
  "jsx-a11y/scope",
  "react/button-has-type",
  "react/default-props-match-prop-types",
  "react/display-name",
  "react/forbid-prop-types",
  "react/jsx-boolean-value",
  "react/jsx-filename-extension",
  "react/jsx-key",
  "react/jsx-no-bind",
  "react/jsx-no-comment-textnodes",
  "react/jsx-no-duplicate-props",
  "react/jsx-no-undef",
  "react/jsx-uses-react",
  "react/jsx-uses-vars",
  "react/jsx-no-target-blank",
  "react/jsx-pascal-case",
  "react/no-access-state-in-setstate",
  "react/no-array-index-key",
  "react/no-children-prop",
  "react/no-danger",
  "react/no-danger-with-children",
  "react/no-deprecated",
  "react/no-find-dom-node",
  "react/no-is-mounted",
  "react/no-multi-comp",
  "react/no-render-return-value",
  "react/no-string-refs",
  "react/no-unescaped-entities",
  "react/no-unknown-property",
  "react/no-unused-prop-types",
  "react/prefer-es6-class",
  "react/prop-types",
  "react/self-closing-comp",
  "react-hooks/rules-of-hooks",
  "@typescript-eslint/adjacent-overload-signatures",
  "@typescript-eslint/array-type",
  "@typescript-eslint/ban-ts-comment",
  "@typescript-eslint/ban-tslint-comment",
  "@typescript-eslint/ban-types",
  "@typescript-eslint/class-literal-property-style",
  "@typescript-eslint/consistent-type-assertions",
  "@typescript-eslint/consistent-type-definitions",
  "@typescript-eslint/dot-notation",
  "@typescript-eslint/explicit-member-accessibility",
  "@typescript-eslint/member-ordering",
  "@typescript-eslint/method-signature-style",
  "@typescript-eslint/no-array-constructor",
  "@typescript-eslint/no-confusing-non-null-assertion",
  "@typescript-eslint/no-dupe-class-members",
  "@typescript-eslint/no-empty-function",
  "@typescript-eslint/no-empty-interface",
  "@typescript-eslint/no-duplicate-enum-values",
  "@typescript-eslint/no-extra-semi",
  "@typescript-eslint/no-extra-non-null-assertion",
  "@typescript-eslint/no-inferrable-types",
  "@typescript-eslint/no-invalid-void-type",
  "@typescript-eslint/no-loop-func",
  "@typescript-eslint/no-loss-of-precision",
  "@typescript-eslint/no-misused-new",
  "@typescript-eslint/no-namespace",
  "@typescript-eslint/no-non-null-asserted-optional-chain",
  "@typescript-eslint/no-redeclare",
  "@typescript-eslint/no-require-imports",
  "@typescript-eslint/no-shadow",
  "@typescript-eslint/no-this-alias",
  "@typescript-eslint/no-unsafe-declaration-merging",
  "@typescript-eslint/triple-slash-reference",
  "@typescript-eslint/typedef",
  "@typescript-eslint/unified-signatures",
  "@typescript-eslint/no-unnecessary-parameter-property-assignment",
  "@typescript-eslint/no-unnecessary-type-constraint",
  "@typescript-eslint/no-useless-constructor",
  "@typescript-eslint/no-useless-empty-export",
  "@typescript-eslint/no-unused-expressions",
  "@typescript-eslint/no-unused-vars",
  "@typescript-eslint/no-use-before-define",
  "@typescript-eslint/no-var-requires",
  "@typescript-eslint/no-wrapper-object-types",
  "@typescript-eslint/prefer-as-const",
  "@typescript-eslint/prefer-namespace-keyword",
  "@typescript-eslint/restrict-plus-operands"
];
const BUILTIN_RULES = new Map(BUILTIN_RULE_IDS.map((ruleId) => [ruleId, createBuiltinRule(ruleId)]));

class UtooLint {
  static get version() {
    return version;
  }

  static get configType() {
    return "flat";
  }

  static get defaultConfig() {
    return [];
  }

  static async fromOptionsModule(optionsURL) {
    if (!(optionsURL instanceof URL)) {
      throw new TypeError("Argument must be a URL object");
    }
    const loaded = await import(optionsURL.href);
    return new UtooLint(loaded.default ?? loaded);
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
    const customRuleConfig = [mergedOptions.baseConfig, mergedOptions.overrideConfig].filter(Boolean);
    const customRuleFilterMap = customRuleMapForConfig(customRuleConfig, new Map());
    const nativeOptions = lintOptionsWithoutCustomRules(mergedOptions, customRuleFilterMap);
    const report = lintFiles(patterns, nativeOptions);
    throwOnUnmatchedPatternDiagnostics(report, nativeOptions);
    const results = reportToESLintResults(report, {
      cwd: mergedOptions.cwd,
      filePaths: reportFilePaths(report, mergedOptions.cwd, explicitLintFilePaths(report.filePaths ?? patterns, mergedOptions.cwd)),
      ruleSeverityForFile: (filePath) => ruleSeverityMapForOptions(nativeOptions, filePath)
    });
    appendCustomLintFileMessages(results, customRuleConfig, mergedOptions);
    return maybeFilterQuietResults(results, mergedOptions);
  }

  async lintText(code, options = {}) {
    if (typeof code !== "string") {
      throw new TypeError("code must be a string");
    }

    const mergedOptions = mergeLintOptions(this.options, options);
    const filePath = normalizeESLintFilePath(textFilePathForOptions(options, "<text>"), mergedOptions.cwd);
    const customRuleConfig = [mergedOptions.baseConfig, mergedOptions.overrideConfig].filter(Boolean);
    const customRuleMap = customRuleMapForConfig(customRuleConfig, new Map(), filePath, mergedOptions.cwd);
    const customRuleFilterMap = customRuleMapForConfig(customRuleConfig, new Map());
    const nativeOptions = lintOptionsWithoutCustomRules(mergedOptions, customRuleFilterMap);
    const report = lintText(code, nativeOptions);
    const results = reportToESLintResults(report, {
      source: code,
      filePath,
      includeEmptyTextResult: report.files !== 0 || (report.diagnostics?.length ?? 0) > 0,
      ruleSeverityForFile: (filePath) => ruleSeverityMapForOptions(nativeOptions, filePath)
    });
    if (report.files !== 0) {
      appendCustomLintTextMessages(results, code, filePath, customRuleConfig, customRuleMap, mergedOptions);
    }
    return maybeFilterQuietResults(results, mergedOptions);
  }

  async isPathIgnored(filePath) {
    return isPathIgnored(filePath, mergeLintOptions(this.options, {}));
  }

  async calculateConfigForFile(filePath) {
    return publicCalculatedConfig(eslintConstructorOptions(this.options), filePath);
  }

  async findConfigFile(filePath) {
    const options = eslintConstructorOptions(this.options);
    if (options.noConfig) {
      return undefined;
    }
    if (filePath) {
      return configPathForFile(options, filePath);
    }
    return configPathForOptions(options);
  }

  getRulesMetaForResults(results) {
    if (!Array.isArray(results)) {
      throw new Error("'results' must be an array");
    }
    const options = eslintConstructorOptions(this.options);
    const customRuleConfig = [options.baseConfig, options.overrideConfig].filter(Boolean);
    const rulesByFilePath = new Map();
    return rulesMetaForResults(results, (ruleId, result) => {
      if (customRuleConfig.length === 0 || typeof result.filePath !== "string") {
        return undefined;
      }
      const filePath = normalizeESLintFilePath(result.filePath, options.cwd);
      if (!rulesByFilePath.has(filePath)) {
        rulesByFilePath.set(filePath, customRuleMapForConfig(customRuleConfig, new Map(), filePath, options.cwd));
      }
      return rulesByFilePath.get(filePath).get(ruleId)?.meta;
    });
  }

  hasFlag(flag) {
    return hasFlagInOptions(this.options, flag);
  }

  async loadFormatter(name = "stylish") {
    const eslint = this;
    return {
      format(results) {
        return formatResultsByName(results, name, {
          rulesMeta: (results) => eslint.getRulesMetaForResults(results)
        });
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
    this.plugins = new Map();
  }

  executeOnFiles(patterns) {
    const mergedOptions = eslintConstructorOptions(this.options);
    const report = lintFiles(patterns, mergedOptions);
    throwOnUnmatchedPatternDiagnostics(report, mergedOptions);
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

  getRules() {
    return new Linter().getRules();
  }

  addPlugin(name, pluginObject) {
    this.plugins.set(name, pluginObject);
  }

  resolveFileGlobPatterns(patterns) {
    return normalizeStringArray(Array.isArray(patterns) ? patterns : [patterns], "patterns");
  }

  isPathIgnored(filePath) {
    return isPathIgnored(filePath, eslintConstructorOptions(this.options));
  }

  getConfigForFile(filePath) {
    return publicCalculatedConfig(eslintConstructorOptions(this.options), filePath);
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
      report.exitCode = exitCodeForDiagnostics(report.diagnostics);
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
  const requestedPath = textFilePathForOptions(options, "text.js");
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
    report.exitCode = exitCodeForDiagnostics(report.diagnostics);
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
    config: options.config ?? options.configFile,
    ignorePath: options.ignorePath,
    ignorePatterns: options.ignorePatterns,
    noIgnore: options.noIgnore ?? options.ignore === false,
    baseConfig: options.baseConfig,
    noConfig: options.noConfig,
    fix: options.fix,
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

function flagsFromOptions(options = {}) {
  return Array.isArray(options.flags) ? [...options.flags] : [];
}

function hasFlagInOptions(options, flag) {
  return flagsFromOptions(options).includes(flag);
}

function calculatedConfig(options = {}, filePath) {
  const configData = mergeConfigData(
    mergeConfigData(configDataFromConfig(options.baseConfig, filePath, options.cwd), configDataFromFileConfig(options, filePath)),
    configDataFromConfig(options.overrideConfig, filePath, options.cwd)
  );
  return {
    ...configData,
    rules: {
      ...rulesFromNativeRuleList(options.rules),
      ...rulesFromConfig(options.baseConfig, filePath, options.cwd),
      ...rulesFromFileConfig(options, filePath),
      ...rulesFromConfig(options.overrideConfig, filePath, options.cwd)
    }
  };
}

function configDataFromConfig(config, filePath, cwd) {
  if (!config) {
    return {};
  }
  if (Array.isArray(config)) {
    return config.reduce((result, entry) => mergeConfigData(result, configDataFromConfig(entry, filePath, cwd)), {});
  }
  if (!configAppliesToFile(config, filePath, cwd)) {
    return {};
  }

  const result = {};
  if (config.settings && typeof config.settings === "object") {
    result.settings = { ...config.settings };
  }
  if (config.languageOptions && typeof config.languageOptions === "object") {
    result.languageOptions = { ...config.languageOptions };
  }
  if (config.parserOptions && typeof config.parserOptions === "object") {
    result.parserOptions = { ...config.parserOptions };
  }
  if (config.globals && typeof config.globals === "object") {
    result.globals = { ...config.globals };
  }
  if (config.env && typeof config.env === "object") {
    result.env = { ...config.env };
  }
  if (config.parser != null) {
    result.parser = config.parser;
  }
  return result;
}

function mergeConfigData(base, override) {
  const result = { ...base, ...override };
  if (base.settings || override.settings) {
    result.settings = { ...(base.settings ?? {}), ...(override.settings ?? {}) };
  }
  if (base.languageOptions || override.languageOptions) {
    result.languageOptions = { ...(base.languageOptions ?? {}), ...(override.languageOptions ?? {}) };
  }
  if (base.parserOptions || override.parserOptions) {
    result.parserOptions = { ...(base.parserOptions ?? {}), ...(override.parserOptions ?? {}) };
  }
  if (base.globals || override.globals) {
    result.globals = { ...(base.globals ?? {}), ...(override.globals ?? {}) };
  }
  if (base.env || override.env) {
    result.env = { ...(base.env ?? {}), ...(override.env ?? {}) };
  }
  return result;
}

function publicCalculatedConfig(options = {}, filePath) {
  const config = calculatedConfig(options, filePath);
  return {
    ...config,
    rules: Object.fromEntries(
      Object.entries(config.rules ?? {}).map(([rule, value]) => [rule, publicRuleConfigValue(value)])
    )
  };
}

function publicRuleConfigValue(value) {
  if (Array.isArray(value)) {
    const [severity, ...rest] = value;
    return [ruleConfigSeverity(severity), ...rest];
  }
  return [ruleConfigSeverity(value)];
}

function rulesFromNativeRuleList(rules) {
  if (!rules) {
    return {};
  }
  const values = Array.isArray(rules) ? rules : String(rules).split(",");
  const result = {};
  for (const rule of values) {
    const name = String(rule).trim();
    if (name) {
      result[name] = "warn";
    }
  }
  return result;
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

  const configPath = filePath ? configPathForFile(options, filePath) : configPathForOptions(options);
  if (!configPath) {
    return {};
  }

  const config = readConfig(configPath, options.cwd);
  return rulesFromConfig(config, filePath, options.cwd);
}

function configDataFromFileConfig(options, filePath) {
  if (options.noConfig) {
    return {};
  }

  const configPath = filePath ? configPathForFile(options, filePath) : configPathForOptions(options);
  if (!configPath) {
    return {};
  }

  const config = readConfig(configPath, options.cwd);
  return configDataFromConfig(config, filePath, options.cwd);
}

function configAppliesToFile(config, filePath, cwd) {
  if (!filePath) {
    return true;
  }

  const normalized = normalizeIgnoredPath(filePath, cwd ?? process.cwd());
  const files = normalizeConfigPatterns(config.files);
  if (files.length > 0 && !files.some((pattern) => matchesConfigFilePattern(normalized, normalizeIgnoredPattern(pattern)))) {
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
  return configPathFromDirectory(cwd);
}

function configPathForFile(options, filePath) {
  if (options.config) {
    return resolvePath(options.cwd ?? process.cwd(), options.config);
  }
  return configPathFromDirectory(configSearchDirectoryForFile(filePath, options.cwd));
}

function configSearchDirectoryForFile(filePath, cwd) {
  const absolute = normalizeESLintFilePath(filePath, cwd);
  try {
    if (statSync(absolute).isDirectory()) {
      return absolute;
    }
  } catch {
    // Non-existent filenames are common for editor integrations.
  }
  return dirname(absolute);
}

function configPathFromDirectory(directory) {
  let current = resolvePath(directory);
  while (true) {
    for (const candidate of CONFIG_FILENAMES) {
      const path = resolvePath(current, candidate);
      if (existsSync(path)) {
        return path;
      }
    }
    const parent = dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}

function readConfig(path, cwd) {
  if (isJavaScriptConfigPath(path)) {
    return readJavaScriptConfig(path, cwd);
  }

  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`utoo-lint unable to read config ${path}: ${error.message}`);
  }
}

function readJavaScriptConfig(path, cwd) {
  const result = spawnSync(process.execPath, ["--input-type=module", "--eval", JAVASCRIPT_CONFIG_LOADER_SCRIPT, path], {
    cwd: cwd ?? process.cwd(),
    encoding: "utf8"
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`utoo-lint unable to read config ${path}: ${(result.stderr ?? "").trim() || "JavaScript config loader failed"}`);
  }
  try {
    return JSON.parse(result.stdout);
  } catch (error) {
    throw new Error(`utoo-lint unable to read config ${path}: ${error.message}`);
  }
}

function isJavaScriptConfigPath(path) {
  return JAVASCRIPT_CONFIG_EXTENSIONS.has(extname(path));
}

function withTemporaryConfig(options, callback) {
  const fileConfigPath = !options.noConfig ? configPathForOptions(options) : undefined;
  const shouldMaterializeFileConfig = fileConfigPath && isJavaScriptConfigPath(fileConfigPath);
  const fileConfig = shouldMaterializeFileConfig ? readConfig(fileConfigPath, options.cwd) : undefined;
  const inlineRules = {
    ...rulesFromConfig(fileConfig),
    ...rulesFromConfig(options.baseConfig),
    ...rulesFromConfig(options.overrideConfig)
  };
  if (Object.keys(inlineRules).length === 0) {
    if (shouldMaterializeFileConfig) {
      return callback({
        ...options,
        config: undefined,
        noConfig: true
      });
    }
    return callback(options);
  }

  const rules = runtimeRulesFromConfigs(fileConfig, options.baseConfig, options.overrideConfig);
  const enabledRules = enabledRuleNamesFromConfigs(fileConfig, options.baseConfig, options.overrideConfig);
  if (!hasRuleOptions(rules)) {
    return callback({
      ...options,
      config: shouldMaterializeFileConfig ? undefined : options.config,
      noConfig: shouldMaterializeFileConfig ? true : options.noConfig ?? true,
      rules: options.rules ?? enabledRules
    });
  }

  const tmp = mkdtempSync(join(tmpdir(), "utoo-lint-config-"));
  const configPath = join(tmp, "utoo.json");
  try {
    writeFileSync(configPath, JSON.stringify({ rules }));
    return callback({
      ...options,
      config: shouldMaterializeFileConfig ? configPath : options.config ?? configPath,
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

function runtimeRulesFromConfigs(...configs) {
  const rules = {};
  for (const config of configs) {
    Object.assign(rules, runtimeRulesFromConfig(config));
  }
  return rules;
}

function runtimeRulesFromConfig(config) {
  if (!config) {
    return {};
  }
  if (Array.isArray(config)) {
    return config.reduce((rules, entry) => ({
      ...rules,
      ...runtimeRulesFromConfig(entry)
    }), {});
  }

  const rules = {};
  for (const [rule, value] of Object.entries(rulesFromConfig(config))) {
    if (ruleConfigSeverity(value) > 0) {
      rules[rule] = value;
    }
  }
  return rules;
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

async function loadESLint() {
  return UtooLint;
}

class Linter {
  static get version() {
    return version;
  }

  constructor(options = {}) {
    this.flags = flagsFromOptions(options);
    this.rules = new Map();
    this.parsers = new Map();
    this.sourceCode = null;
    this.suppressedMessages = [];
    this.times = { passes: [] };
    this.fixPassCount = 0;
  }

  verify(code, config = {}, options = {}) {
    if (typeof code !== "string") {
      throw new TypeError("code must be a string");
    }

    const verifyOptions = typeof options === "string" ? { filename: options } : { ...options };
    const filePath = verifyOptions.filename ?? verifyOptions.filePath ?? "input.js";
    const normalizedFilePath = normalizeESLintFilePath(filePath, verifyOptions.cwd);
    const sourceCode = createLinterSourceCode(
      code,
      parserForConfig(config, this.parsers, normalizedFilePath, verifyOptions.cwd),
      parserOptionsForConfig(config, normalizedFilePath, verifyOptions.cwd)
    );
    const customRuleMap = customRuleMapForConfig(config, this.rules, normalizedFilePath, verifyOptions.cwd);
    const customRuleFilterMap = customRuleMapForConfig(config, this.rules);
    const customRules = customRuleEntriesForConfig(config, customRuleMap, normalizedFilePath, verifyOptions.cwd);
    const nativeConfig = configWithoutCustomRules(config, customRuleFilterMap);
    const lintOptions = {
      cwd: verifyOptions.cwd,
      filePath,
      noConfig: true,
      noIgnore: true,
      warnIgnored: false,
      overrideConfig: nativeConfig
    };
    const report = lintText(code, lintOptions);
    const ruleSeverities = ruleSeverityMapForOptions(lintOptions, normalizedFilePath);
    this.sourceCode = sourceCode;
    const customRuleMessages = runCustomLinterRules(customRules, sourceCode, {
      cwd: verifyOptions.cwd,
      filename: filePath,
      config: calculatedConfig({ cwd: verifyOptions.cwd, noConfig: true, overrideConfig: config }, normalizedFilePath)
    });
    const customRuleFilter = applyDisableDirectives(customRuleMessages, sourceCode);
    this.suppressedMessages = customRuleFilter.suppressedMessages;
    this.times = { passes: [] };
    this.fixPassCount = 0;
    return [
      ...(report.diagnostics ?? []).map((diagnostic) => diagnosticToESLintMessage(diagnostic, ruleSeverities)),
      ...customRuleFilter.messages
    ];
  }

  verifyAndFix(code, config = {}, options = {}) {
    let output = code;
    let fixed = false;
    let fixPassCount = 0;
    for (let pass = 0; pass < MAX_AUTOFIX_PASSES; pass += 1) {
      const messages = this.verify(output, config, options);
      const fixedOutput = applyRuleFixes(output, messages.flatMap((message) => ruleFixItems(message.fix)));
      if (fixedOutput === output) {
        this.fixPassCount = fixPassCount;
        return {
          fixed,
          messages,
          output
        };
      }
      fixed = true;
      fixPassCount += 1;
      output = fixedOutput;
    }
    const messages = this.verify(output, config, options);
    this.fixPassCount = fixPassCount;
    return {
      fixed,
      messages,
      output
    };
  }

  getSourceCode() {
    return this.sourceCode;
  }

  getSuppressedMessages() {
    return this.suppressedMessages;
  }

  getTimes() {
    return this.times;
  }

  getFixPassCount() {
    return this.fixPassCount;
  }

  hasFlag(flag) {
    return this.flags.includes(flag);
  }

  getRules() {
    return new Map([...BUILTIN_RULES, ...this.rules]);
  }

  defineRule(ruleId, rule) {
    if (typeof ruleId !== "string" || ruleId.length === 0) {
      throw new TypeError("Linter#defineRule requires a rule id string");
    }
    this.rules.set(ruleId, rule);
  }

  defineRules(rules) {
    if (typeof rules !== "object" || rules === null) {
      throw new TypeError("Linter#defineRules requires a rules object");
    }
    for (const [ruleId, rule] of Object.entries(rules)) {
      this.defineRule(ruleId, rule);
    }
  }

  defineParser(parserId, parser) {
    if (typeof parserId !== "string" || parserId.length === 0) {
      throw new TypeError("Linter#defineParser requires a parser id string");
    }
    this.parsers.set(parserId, parser);
  }
}

function parserForConfig(config, parsers, filePath, cwd) {
  let parser = null;
  for (const entry of matchingConfigEntries(config, filePath, cwd)) {
    parser = entry.languageOptions?.parser ?? entry.parser ?? parser;
  }
  if (typeof parser === "string") {
    return parsers.get(parser) ?? null;
  }
  return parser && typeof parser === "object" ? parser : null;
}

function parserOptionsForConfig(config, filePath, cwd) {
  const configData = configDataFromConfig(config, filePath, cwd);
  return {
    ...(configData.parserOptions ?? {}),
    ...(configData.languageOptions?.parserOptions ?? {}),
    filename: filePath,
    filePath,
    cwd
  };
}

function customRuleEntriesForConfig(config, rules, filePath, cwd) {
  const entries = new Map();
  for (const [ruleId, ruleConfig] of ruleConfigEntries(config, filePath, cwd)) {
    if (!rules.has(ruleId)) {
      continue;
    }
    const severity = ruleConfigSeverity(ruleConfig);
    if (severity === 0) {
      entries.delete(ruleId);
      continue;
    }
    entries.set(ruleId, {
      ruleId,
      rule: rules.get(ruleId),
      severity,
      options: Array.isArray(ruleConfig) ? ruleConfig.slice(1) : []
    });
  }
  return [...entries.values()];
}

function customRuleMapForConfig(config, definedRules, filePath, cwd) {
  return new Map([
    ...pluginRulesForConfig(config, filePath, cwd),
    ...definedRules
  ]);
}

function pluginRulesForConfig(config, filePath, cwd) {
  const rules = new Map();
  for (const entry of matchingConfigEntries(config, filePath, cwd)) {
    if (!entry.plugins || typeof entry.plugins !== "object") {
      continue;
    }
    for (const [pluginName, plugin] of Object.entries(entry.plugins)) {
      if (!plugin?.rules || typeof plugin.rules !== "object") {
        continue;
      }
      for (const [ruleName, rule] of Object.entries(plugin.rules)) {
        rules.set(`${pluginName}/${ruleName}`, rule);
      }
    }
  }
  return rules;
}

function matchingConfigEntries(config, filePath = undefined, cwd = undefined) {
  if (!config) {
    return [];
  }
  if (Array.isArray(config)) {
    return config.flatMap((entry) => matchingConfigEntries(entry, filePath, cwd));
  }
  if (typeof config !== "object" || !configAppliesToFile(config, filePath, cwd)) {
    return [];
  }
  return [config];
}

function ruleConfigEntries(config, filePath = undefined, cwd = undefined) {
  if (Array.isArray(config)) {
    return config.flatMap((item) => ruleConfigEntries(item, filePath, cwd));
  }
  if (!config || typeof config !== "object" || !config.rules || typeof config.rules !== "object") {
    return [];
  }
  if (!configAppliesToFile(config, filePath, cwd)) {
    return [];
  }
  return Object.entries(config.rules);
}

function configWithoutCustomRules(config, rules) {
  if (Array.isArray(config)) {
    return config.map((item) => configWithoutCustomRules(item, rules));
  }
  if (!config || typeof config !== "object" || !config.rules || typeof config.rules !== "object") {
    return config;
  }

  let removedCustomRule = false;
  const nativeRules = {};
  for (const [ruleId, ruleConfig] of Object.entries(config.rules)) {
    if (rules.has(ruleId)) {
      removedCustomRule = true;
      continue;
    }
    nativeRules[ruleId] = ruleConfig;
  }
  return removedCustomRule ? { ...config, rules: nativeRules } : config;
}

function lintOptionsWithoutCustomRules(options, rules) {
  if (rules.size === 0) {
    return options;
  }
  return {
    ...options,
    baseConfig: configWithoutCustomRules(options.baseConfig, rules),
    overrideConfig: configWithoutCustomRules(options.overrideConfig, rules)
  };
}

function appendCustomLintTextMessages(results, code, filePath, config, rules, options) {
  const customRules = customRuleEntriesForConfig(config, rules, filePath, options.cwd);
  if (customRules.length === 0) {
    return results;
  }
  const sourceCode = createLinterSourceCode(code);
  const messages = runCustomLinterRules(customRules, sourceCode, {
    cwd: options.cwd,
    filename: filePath,
    config: calculatedConfig({ cwd: options.cwd, noConfig: true, baseConfig: options.baseConfig, overrideConfig: options.overrideConfig }, filePath)
  });
  const filtered = applyDisableDirectives(messages, sourceCode);
  if (filtered.messages.length === 0 && filtered.suppressedMessages.length === 0) {
    return results;
  }

  let result = results.find((item) => item.filePath === filePath);
  if (!result) {
    result = emptyESLintResult(filePath, code);
    results.push(result);
  }
  result.messages.push(...filtered.messages);
  result.suppressedMessages.push(...filtered.suppressedMessages);
  applyResultFixes(result, code, options);
  finalizeESLintResult(result);
  return results;
}

function appendCustomLintFileMessages(results, config, options) {
  for (const result of results) {
    const filePath = result.filePath;
    const rules = customRuleMapForConfig(config, new Map(), filePath, options.cwd);
    const customRules = customRuleEntriesForConfig(config, rules, filePath, options.cwd);
    if (customRules.length === 0) {
      continue;
    }
    let code;
    try {
      code = readFileSync(filePath, "utf8");
    } catch {
      continue;
    }
    const sourceCode = createLinterSourceCode(code);
    const messages = runCustomLinterRules(customRules, sourceCode, {
      cwd: options.cwd,
      filename: filePath,
      config: calculatedConfig({ cwd: options.cwd, noConfig: true, baseConfig: options.baseConfig, overrideConfig: options.overrideConfig }, filePath)
    });
    const filtered = applyDisableDirectives(messages, sourceCode);
    if (filtered.messages.length === 0 && filtered.suppressedMessages.length === 0) {
      continue;
    }
    result.messages.push(...filtered.messages);
    result.suppressedMessages.push(...filtered.suppressedMessages);
    applyResultFixes(result, code, options);
    finalizeESLintResult(result);
  }
  return results;
}

function applyResultFixes(result, code, options) {
  if (!options.fix) {
    return;
  }
  const output = applyRuleFixes(code, result.messages.flatMap((message) => ruleFixItems(message.fix)));
  if (output !== code) {
    result.output = output;
  }
}

function runCustomLinterRules(ruleEntries, sourceCode, options) {
  if (ruleEntries.length === 0) {
    return [];
  }

  const messages = [];
  const program = sourceCode.ast ?? { type: "Program", range: [0, sourceCode.text.length] };
  for (const ruleEntry of ruleEntries) {
    const context = createCustomRuleContext(ruleEntry, sourceCode, options, messages);
    const listeners = customRuleListeners(ruleEntry.rule, context);
    if (customRuleChildNodes(program, sourceCode.visitorKeys).length > 0) {
      traverseCustomRuleAst(program, listeners, context, sourceCode.visitorKeys);
    } else {
      runCustomRuleTokenListeners(program, sourceCode.tokens, listeners, context);
    }
  }
  return messages;
}

function applyDisableDirectives(messages, sourceCode) {
  if (messages.length === 0) {
    return { messages, suppressedMessages: [] };
  }
  const directives = sourceCode.getDisableDirectives()
    .filter((directive) => directive.node?.loc?.start?.line)
    .sort((left, right) => left.node.loc.start.line - right.node.loc.start.line);
  if (directives.length === 0) {
    return { messages, suppressedMessages: [] };
  }

  const kept = [];
  const suppressed = [];
  for (const message of messages) {
    const directive = disableDirectiveForMessage(message, directives);
    if (directive) {
      suppressed.push({
        ...message,
        suppressions: [{
          kind: "directive",
          justification: directive.justification
        }]
      });
    } else {
      kept.push(message);
    }
  }
  return { messages: kept, suppressedMessages: suppressed };
}

function disableDirectiveForMessage(message, directives) {
  const active = {
    all: null,
    allEnabledRules: new Set(),
    rules: new Map()
  };
  for (const directive of directives) {
    const line = directive.node.loc.start.line;
    if (directive.type === "eslint-disable-line" && line === message.line && disableDirectiveMatchesRule(directive, message.ruleId)) {
      return directive;
    }
    if (directive.type === "eslint-disable-next-line" && line + 1 === message.line && disableDirectiveMatchesRule(directive, message.ruleId)) {
      return directive;
    }
    if (line > message.line) {
      break;
    }
    if (directive.type === "eslint-disable") {
      if (directive.ruleId) {
        active.rules.set(directive.ruleId, directive);
        active.allEnabledRules.delete(directive.ruleId);
      } else {
        active.all = directive;
        active.allEnabledRules.clear();
      }
    } else if (directive.type === "eslint-enable") {
      if (directive.ruleId) {
        active.rules.delete(directive.ruleId);
        if (active.all) {
          active.allEnabledRules.add(directive.ruleId);
        }
      } else {
        active.all = null;
        active.allEnabledRules.clear();
        active.rules.clear();
      }
    }
  }
  if (active.rules.has(message.ruleId)) {
    return active.rules.get(message.ruleId);
  }
  if (active.all && !active.allEnabledRules.has(message.ruleId)) {
    return active.all;
  }
  return null;
}

function disableDirectiveMatchesRule(directive, ruleId) {
  return directive.ruleId == null || directive.ruleId === ruleId;
}

function traverseCustomRuleAst(node, listeners, context, visitorKeys, seen = new Set(), ancestors = [], siblings = {}) {
  if (!node || typeof node !== "object" || typeof node.type !== "string" || seen.has(node)) {
    return;
  }
  seen.add(node);
  for (const listener of customRuleMatchingListeners(listeners, node, false, ancestors, siblings, visitorKeys)) {
    context.setCurrentNode(node);
    listener(node);
  }
  const children = customRuleChildNodes(node, visitorKeys);
  for (const [index, child] of children.entries()) {
    traverseCustomRuleAst(child, listeners, context, visitorKeys, seen, [...ancestors, node], {
      previous: children[index - 1] ?? null,
      previousAll: children.slice(0, index)
    });
  }
  for (const listener of customRuleMatchingListeners(listeners, node, true, ancestors, siblings, visitorKeys)) {
    context.setCurrentNode(node);
    listener(node);
  }
}

function customRuleMatchingListeners(listeners, node, exit, ancestors = [], siblings = {}, visitorKeys = null) {
  const matches = [];
  for (const [selector, listener] of Object.entries(listeners)) {
    if (typeof listener !== "function" || !customRuleSelectorMatches(selector, node, exit, ancestors, siblings, visitorKeys)) {
      continue;
    }
    matches.push(listener);
  }
  return matches;
}

function customRuleSelectorMatches(selector, node, exit, ancestors = [], siblings = {}, visitorKeys = null) {
  const suffix = ":exit";
  const isExit = selector.endsWith(suffix);
  if (isExit !== exit) {
    return false;
  }
  const expression = isExit ? selector.slice(0, -suffix.length) : selector;
  const childSelector = customRuleSplitTopLevelSelector(expression, ">");
  if (childSelector) {
    const parent = ancestors.at(-1);
    return Boolean(parent)
      && customRuleSimpleSelectorMatches(childSelector[0].trim(), parent, visitorKeys)
      && customRuleSimpleSelectorMatches(childSelector[1].trim(), node, visitorKeys);
  }
  const adjacentSelector = customRuleSplitTopLevelSelector(expression, "+");
  if (adjacentSelector) {
    return Boolean(siblings.previous)
      && customRuleSimpleSelectorMatches(adjacentSelector[0].trim(), siblings.previous, visitorKeys)
      && customRuleSimpleSelectorMatches(adjacentSelector[1].trim(), node, visitorKeys);
  }
  const siblingSelector = customRuleSplitTopLevelSelector(expression, "~");
  if (siblingSelector) {
    return (siblings.previousAll ?? []).some((sibling) => customRuleSimpleSelectorMatches(siblingSelector[0].trim(), sibling, visitorKeys))
      && customRuleSimpleSelectorMatches(siblingSelector[1].trim(), node, visitorKeys);
  }
  const descendantSelector = customRuleSplitTopLevelDescendantSelector(expression);
  if (descendantSelector) {
    return ancestors.some((ancestor) => customRuleSimpleSelectorMatches(descendantSelector[0].trim(), ancestor, visitorKeys))
      && customRuleSimpleSelectorMatches(descendantSelector[1].trim(), node, visitorKeys);
  }
  return customRuleSimpleSelectorMatches(expression, node, visitorKeys);
}

function customRuleSimpleSelectorMatches(expression, node, visitorKeys = null) {
  const hasSelector = expression.match(/^(.+?):has\((.+)\)$/u);
  if (hasSelector) {
    return customRuleSimpleSelectorMatches(hasSelector[1].trim(), node, visitorKeys)
      && customRuleDescendants(node, visitorKeys).some((descendant) => (
        customRuleSplitSelectorList(hasSelector[2]).some((selector) => customRuleSimpleSelectorMatches(selector.trim(), descendant, visitorKeys))
      ));
  }
  const notSelector = expression.match(/^(.+?):not\((.+)\)$/u);
  if (notSelector) {
    return customRuleSimpleSelectorMatches(notSelector[1].trim(), node, visitorKeys)
      && !customRuleSimpleSelectorMatches(notSelector[2].trim(), node, visitorKeys);
  }
  const matchesSelector = expression.match(/^(.*?):matches\((.+)\)$/u);
  if (matchesSelector) {
    const prefix = matchesSelector[1].trim();
    if (prefix && !customRuleSimpleSelectorMatches(prefix, node, visitorKeys)) {
      return false;
    }
    return customRuleSplitSelectorList(matchesSelector[2]).some((selector) => (
      customRuleSimpleSelectorMatches(selector.trim(), node, visitorKeys)
    ));
  }
  if (expression === node.type) {
    return true;
  }
  const match = expression.match(/^([A-Za-z_$][\w$-]*|\*)?(?:\[([^\]]+)\])?$/u);
  if (!match) {
    return false;
  }
  const [, type = "*", attribute] = match;
  if (type !== "*" && type !== node.type) {
    return false;
  }
  return attribute ? customRuleAttributeSelectorMatches(node, attribute.trim()) : type === "*" || type === node.type;
}

function customRuleDescendants(node, visitorKeys, seen = new Set()) {
  const descendants = [];
  for (const child of customRuleChildNodes(node, visitorKeys)) {
    if (seen.has(child)) {
      continue;
    }
    seen.add(child);
    descendants.push(child, ...customRuleDescendants(child, visitorKeys, seen));
  }
  return descendants;
}

function customRuleSplitTopLevelSelector(expression, separator) {
  let state = customRuleSelectorScanState();
  for (let index = 0; index < expression.length; index += 1) {
    state = customRuleUpdateSelectorScanState(state, expression[index]);
    if (state.depth === 0 && !state.quote && expression[index] === separator) {
      return [expression.slice(0, index), expression.slice(index + 1)];
    }
  }
  return null;
}

function customRuleSplitTopLevelDescendantSelector(expression) {
  let state = customRuleSelectorScanState();
  for (let index = 0; index < expression.length; index += 1) {
    state = customRuleUpdateSelectorScanState(state, expression[index]);
    if (state.depth === 0 && !state.quote && /\s/u.test(expression[index])) {
      const left = expression.slice(0, index).trim();
      const right = expression.slice(index).trim();
      return left && right ? [left, right] : null;
    }
  }
  return null;
}

function customRuleSplitSelectorList(value) {
  const selectors = [];
  let state = customRuleSelectorScanState();
  let start = 0;
  for (let index = 0; index < value.length; index += 1) {
    state = customRuleUpdateSelectorScanState(state, value[index]);
    if (state.depth === 0 && !state.quote && value[index] === ",") {
      selectors.push(value.slice(start, index));
      start = index + 1;
    }
  }
  selectors.push(value.slice(start));
  return selectors.filter((selector) => selector.trim());
}

function customRuleSelectorScanState() {
  return { depth: 0, quote: null, escaped: false };
}

function customRuleUpdateSelectorScanState(state, char) {
  if (state.escaped) {
    return { ...state, escaped: false };
  }
  if (char === "\\") {
    return { ...state, escaped: true };
  }
  if (state.quote) {
    return char === state.quote ? { ...state, quote: null } : state;
  }
  if (char === "\"" || char === "'") {
    return { ...state, quote: char };
  }
  if (char === "[" || char === "(") {
    return { ...state, depth: state.depth + 1 };
  }
  if ((char === "]" || char === ")") && state.depth > 0) {
    return { ...state, depth: state.depth - 1 };
  }
  return state;
}

function customRuleAttributeSelectorMatches(node, attribute) {
  const match = attribute.match(/^([\w$.-]+)\s*(!=|=)\s*(.+)$/u);
  if (!match) {
    return customRuleValueByPath(node, attribute) != null;
  }
  const [, path, operator, rawExpected] = match;
  const actual = customRuleValueByPath(node, path);
  const expected = customRuleSelectorValue(rawExpected);
  return operator === "="
    ? String(actual) === expected
    : String(actual) !== expected;
}

function customRuleSelectorValue(raw) {
  const value = raw.trim();
  const quote = value[0];
  if ((quote === "\"" || quote === "'") && value.at(-1) === quote) {
    return value.slice(1, -1);
  }
  return value;
}

function customRuleValueByPath(node, path) {
  return path.split(".").reduce((value, key) => (
    value && typeof value === "object" ? value[key] : undefined
  ), node);
}

function customRuleChildNodes(node, visitorKeys) {
  const keys = Array.isArray(visitorKeys?.[node.type])
    ? visitorKeys[node.type]
    : Object.keys(node).filter((key) => !AST_TRAVERSAL_SKIP_KEYS.has(key));
  const children = [];
  for (const key of keys) {
    const value = node[key];
    const values = Array.isArray(value) ? value : [value];
    for (const child of values) {
      if (child && typeof child === "object" && typeof child.type === "string") {
        children.push(child);
      }
    }
  }
  return children;
}

function runCustomRuleTokenListeners(program, tokens, listeners, context) {
  if (typeof listeners.Program === "function") {
    context.setCurrentNode(program);
    listeners.Program(program);
  }
  for (const node of tokens) {
    if (typeof listeners[node.type] === "function") {
      context.setCurrentNode(node);
      listeners[node.type](node);
    }
  }
  for (let index = tokens.length - 1; index >= 0; index -= 1) {
    const node = tokens[index];
    const exitListener = listeners[`${node.type}:exit`];
    if (typeof exitListener === "function") {
      context.setCurrentNode(node);
      exitListener(node);
    }
  }
  if (typeof listeners["Program:exit"] === "function") {
    context.setCurrentNode(program);
    listeners["Program:exit"](program);
  }
}

function createCustomRuleContext(ruleEntry, sourceCode, options, messages) {
  const filename = options.filename ?? "<input>";
  const cwd = options.cwd ?? "";
  const config = options.config ?? {};
  const languageOptions = config.languageOptions ?? {};
  const parserOptions = languageOptions.parserOptions ?? config.parserOptions ?? {};
  let currentNode = sourceCode.ast ?? null;
  const context = {
    id: ruleEntry.ruleId,
    options: ruleEntry.options,
    filename,
    physicalFilename: filename,
    cwd,
    sourceCode,
    settings: config.settings ?? {},
    parserOptions,
    parserPath: config.parser ?? languageOptions.parser ?? null,
    parserServices: sourceCode.parserServices ?? {},
    languageOptions,
    getCwd() {
      return cwd;
    },
    getFilename() {
      return filename;
    },
    getPhysicalFilename() {
      return filename;
    },
    getSourceCode() {
      return sourceCode;
    },
    getScope() {
      return sourceCode.getScope(currentNode);
    },
    getAncestors() {
      return currentNode ? sourceCode.getAncestors(currentNode) : [];
    },
    getDeclaredVariables(node) {
      return sourceCode.getDeclaredVariables(node);
    },
    markVariableAsUsed(name) {
      return sourceCode.markVariableAsUsed(name, currentNode);
    },
    report(...args) {
      messages.push(customRuleMessageFromReport(ruleEntry, sourceCode, args));
    }
  };
  Object.defineProperty(context, "setCurrentNode", {
    value(node) {
      currentNode = node;
    }
  });
  return context;
}

function customRuleListeners(rule, context) {
  if (typeof rule === "function") {
    return rule(context) ?? {};
  }
  if (typeof rule?.create === "function") {
    return rule.create(context) ?? {};
  }
  return {};
}

function customRuleMessageFromReport(ruleEntry, sourceCode, args) {
  const descriptor = customRuleReportDescriptor(args);
  const node = descriptor.node ?? null;
  const location = customRuleReportLocation(sourceCode, descriptor, node);
  const message = customRuleReportMessage(ruleEntry.rule, descriptor);
  const result = {
    ruleId: ruleEntry.ruleId,
    severity: ruleEntry.severity,
    message,
    line: location.start.line,
    column: location.start.column + 1,
    nodeType: node?.type ?? null
  };
  if (location.end) {
    result.endLine = location.end.line;
    result.endColumn = location.end.column + 1;
  }
  const fix = customRuleFix(sourceCode, descriptor);
  if (fix) {
    result.fix = fix;
  }
  if (Array.isArray(descriptor.suggest)) {
    result.suggestions = customRuleSuggestions(ruleEntry.rule, sourceCode, descriptor.suggest);
  }
  return result;
}

function customRuleReportDescriptor(args) {
  const [first, second, third, fourth] = args;
  if (first && typeof first === "object" && (
    Object.hasOwn(first, "message")
    || Object.hasOwn(first, "messageId")
    || Object.hasOwn(first, "node")
    || Object.hasOwn(first, "loc")
  )) {
    return first;
  }
  if (typeof second === "string") {
    return { node: first, message: second, data: third };
  }
  return { node: first, loc: second, message: third, data: fourth };
}

function customRuleReportMessage(rule, descriptor) {
  if (descriptor.messageId != null) {
    return ruleTesterMessageForId(rule, descriptor.messageId, descriptor.data);
  }
  if (typeof descriptor.message === "string") {
    return replaceRuleMessageData(descriptor.message, descriptor.data);
  }
  return "";
}

function customRuleReportLocation(sourceCode, descriptor, node) {
  const loc = descriptor.loc ?? node?.loc ?? sourceCode.getLoc(node);
  const start = loc?.start ?? loc ?? { line: 1, column: 0 };
  const end = loc?.end ?? null;
  return {
    start: {
      line: start.line ?? 1,
      column: start.column ?? 0
    },
    end: end ? {
      line: end.line ?? start.line ?? 1,
      column: end.column ?? start.column ?? 0
    } : null
  };
}

function customRuleSuggestions(rule, sourceCode, suggestions) {
  return suggestions.map((suggestion) => {
    const result = {
      desc: customRuleSuggestionDescription(rule, suggestion)
    };
    if (suggestion.messageId != null) {
      result.messageId = suggestion.messageId;
    }
    const fix = customRuleSuggestionFix(sourceCode, suggestion);
    if (fix) {
      result.fix = fix;
    }
    return result;
  });
}

function customRuleSuggestionDescription(rule, suggestion) {
  if (typeof suggestion.desc === "string") {
    return replaceRuleMessageData(suggestion.desc, suggestion.data);
  }
  if (suggestion.messageId != null) {
    return ruleTesterMessageForId(rule, suggestion.messageId, suggestion.data);
  }
  return "";
}

function customRuleSuggestionFix(sourceCode, suggestion) {
  return customRuleFix(sourceCode, suggestion);
}

function customRuleFix(sourceCode, descriptor) {
  if (typeof descriptor.fix !== "function") {
    return null;
  }
  const value = descriptor.fix(customRuleFixer(sourceCode));
  const fixes = ruleFixItems(value);
  if (fixes.length === 0) {
    return null;
  }
  return fixes.length === 1 ? fixes[0] : fixes;
}

function customRuleFixer(sourceCode) {
  return {
    insertTextAfter(node, text) {
      const range = sourceCode.getRange(node);
      return { range: [range[1], range[1]], text };
    },
    insertTextAfterRange(range, text) {
      return { range: [range[1], range[1]], text };
    },
    insertTextBefore(node, text) {
      const range = sourceCode.getRange(node);
      return { range: [range[0], range[0]], text };
    },
    insertTextBeforeRange(range, text) {
      return { range: [range[0], range[0]], text };
    },
    remove(node) {
      return this.replaceText(node, "");
    },
    removeRange(range) {
      return this.replaceTextRange(range, "");
    },
    replaceText(node, text) {
      return this.replaceTextRange(sourceCode.getRange(node), text);
    },
    replaceTextRange(range, text) {
      return { range: [range[0], range[1]], text };
    }
  };
}

class SourceCode {
  static splitLines(text) {
    if (typeof text !== "string") {
      throw new TypeError("SourceCode.splitLines requires source text");
    }
    return text.split(/\r\n|\r|\n/u);
  }

  constructor(textOrConfig, astIfNoConfig = null) {
    if (typeof textOrConfig === "string") {
      this.text = textOrConfig;
      this.ast = astIfNoConfig;
      this.parserServices = {};
      this.scopeManager = null;
      this.visitorKeys = null;
      this.hasBOM = false;
    } else if (textOrConfig && typeof textOrConfig === "object" && typeof textOrConfig.text === "string") {
      this.text = textOrConfig.text;
      this.ast = textOrConfig.ast ?? null;
      this.parserServices = textOrConfig.parserServices ?? {};
      this.scopeManager = textOrConfig.scopeManager ?? null;
      this.visitorKeys = textOrConfig.visitorKeys ?? null;
      this.hasBOM = Boolean(textOrConfig.hasBOM);
    } else {
      throw new TypeError("SourceCode requires source text");
    }
    this.lines = SourceCode.splitLines(this.text);
    this.comments = Array.isArray(this.ast?.comments) ? this.ast.comments : [];
    this.tokens = Array.isArray(this.ast?.tokens) ? this.ast.tokens : [];
    this.lineStartIndices = sourceLineStartIndices(this.text);
  }

  getText(node, beforeCount = 0, afterCount = 0) {
    if (node?.range) {
      return this.text.slice(Math.max(node.range[0] - beforeCount, 0), node.range[1] + afterCount);
    }
    return this.text;
  }

  getLines() {
    return this.lines;
  }

  getAllComments() {
    return this.comments;
  }

  getIndexFromLoc(loc) {
    return this.lineStartIndices[Math.max(loc.line - 1, 0)] + loc.column;
  }

  getLocFromIndex(index) {
    const clamped = Math.max(0, Math.min(index, this.text.length));
    let line = 0;
    while (line + 1 < this.lineStartIndices.length && this.lineStartIndices[line + 1] <= clamped) {
      line += 1;
    }
    return {
      line: line + 1,
      column: clamped - this.lineStartIndices[line]
    };
  }

  getRange(node) {
    if (node?.range) {
      return [node.range[0], node.range[1]];
    }
    if (node?.loc) {
      return [this.getIndexFromLoc(node.loc.start), this.getIndexFromLoc(node.loc.end)];
    }
    return [0, this.text.length];
  }

  getLoc(node) {
    if (node?.loc) {
      return node.loc;
    }
    const range = this.getRange(node);
    return {
      start: this.getLocFromIndex(range[0]),
      end: this.getLocFromIndex(range[1])
    };
  }

  getAllTokens() {
    return this.tokens;
  }

  getTokens(node, beforeCount = 0, afterCount = 0) {
    const options = sourceTokenRangeOptions(beforeCount, afterCount);
    const items = sourceTokenItems(this, options);
    if (!node) {
      return sourceApplyTokenFilter(items, options);
    }
    const range = expandSourceRange(this.getRange(node), options.beforeCount, options.afterCount, this.text.length);
    return sourceApplyTokenFilter(sourceItemsInRange(items, range), options);
  }

  getFirstToken(node, skipOrOptions = 0) {
    return sourceForwardToken(this.getTokens(node, sourceTokenOptions(skipOrOptions, "skip")), skipOrOptions);
  }

  getFirstTokens(node, countOrOptions = 1) {
    return sourceForwardTokens(this.getTokens(node, sourceTokenOptions(countOrOptions, "count")), countOrOptions);
  }

  getLastToken(node, skipOrOptions = 0) {
    return sourceBackwardToken(this.getTokens(node, sourceTokenOptions(skipOrOptions, "skip")), skipOrOptions);
  }

  getLastTokens(node, countOrOptions = 1) {
    return sourceBackwardTokens(this.getTokens(node, sourceTokenOptions(countOrOptions, "count")), countOrOptions);
  }

  getTokenBefore(nodeOrToken, skipOrOptions = 0) {
    const options = sourceTokenOptions(skipOrOptions, "skip");
    return sourceBackwardToken(sourceApplyTokenFilter(sourceItemsBefore(sourceTokenItems(this, options), this.getRange(nodeOrToken)[0]), options), options);
  }

  getTokensBefore(nodeOrToken, countOrOptions = 1) {
    const options = sourceTokenOptions(countOrOptions, "count");
    return sourceBackwardTokens(sourceApplyTokenFilter(sourceItemsBefore(sourceTokenItems(this, options), this.getRange(nodeOrToken)[0]), options), options);
  }

  getTokenAfter(nodeOrToken, skipOrOptions = 0) {
    const options = sourceTokenOptions(skipOrOptions, "skip");
    return sourceForwardToken(sourceApplyTokenFilter(sourceItemsAfter(sourceTokenItems(this, options), this.getRange(nodeOrToken)[1]), options), options);
  }

  getTokensAfter(nodeOrToken, countOrOptions = 1) {
    const options = sourceTokenOptions(countOrOptions, "count");
    return sourceForwardTokens(sourceApplyTokenFilter(sourceItemsAfter(sourceTokenItems(this, options), this.getRange(nodeOrToken)[1]), options), options);
  }

  getTokensBetween(left, right, optionsOrCount) {
    const options = sourceTokenOptions(optionsOrCount, "count");
    return sourceForwardTokens(sourceTokensBetween(this, left, right, options), options);
  }

  getFirstTokenBetween(left, right, skipOrOptions = 0) {
    const options = sourceTokenOptions(skipOrOptions, "skip");
    return sourceForwardToken(sourceTokensBetween(this, left, right, options), options);
  }

  getFirstTokensBetween(left, right, countOrOptions = 1) {
    const options = sourceTokenOptions(countOrOptions, "count");
    return sourceForwardTokens(sourceTokensBetween(this, left, right, options), options);
  }

  getLastTokenBetween(left, right, skipOrOptions = 0) {
    const options = sourceTokenOptions(skipOrOptions, "skip");
    return sourceBackwardToken(sourceTokensBetween(this, left, right, options), options);
  }

  getLastTokensBetween(left, right, countOrOptions = 1) {
    const options = sourceTokenOptions(countOrOptions, "count");
    return sourceBackwardTokens(sourceTokensBetween(this, left, right, options), options);
  }

  getTokenByRangeStart(index, options = {}) {
    return sourceTokenItems(this, sourceTokenOptions(options, "skip")).find((token) => token.range?.[0] === index) ?? null;
  }

  getTokenOrCommentBefore(nodeOrToken) {
    return sourceItemsBefore(sourceTokensAndComments(this), this.getRange(nodeOrToken)[0]).at(-1) ?? null;
  }

  getTokenOrCommentAfter(nodeOrToken) {
    return sourceItemsAfter(sourceTokensAndComments(this), this.getRange(nodeOrToken)[1])[0] ?? null;
  }

  getCommentsBefore(nodeOrToken) {
    return sourceItemsBefore(this.comments, this.getRange(nodeOrToken)[0]);
  }

  getCommentsAfter(nodeOrToken) {
    return sourceItemsAfter(this.comments, this.getRange(nodeOrToken)[1]);
  }

  getCommentsInside(node) {
    return sourceItemsInRange(this.comments, this.getRange(node));
  }

  getComments(node) {
    return {
      before: this.getCommentsBefore(node),
      after: this.getCommentsAfter(node),
      inside: this.getCommentsInside(node)
    };
  }

  getJSDocComment(node) {
    return this.getCommentsBefore(node).findLast((comment) => String(comment.value ?? "").startsWith("*")) ?? null;
  }

  commentsExistBetween(left, right) {
    return sourceItemsBetween(this.comments, this.getRange(left)[1], this.getRange(right)[0]).length > 0;
  }

  isSpaceBetween(left, right) {
    return /\s/u.test(this.text.slice(this.getRange(left)[1], this.getRange(right)[0]));
  }

  isSpaceBetweenTokens(left, right) {
    return this.isSpaceBetween(left, right);
  }

  getNodeByRangeIndex(index) {
    return sourceNodeByRangeIndex(this.ast, index);
  }

  getAncestors(node) {
    return node ? sourceAncestorsForNode(this.ast, node) ?? [] : [];
  }

  getDeclaredVariables(node) {
    return typeof this.scopeManager?.getDeclaredVariables === "function" ? this.scopeManager.getDeclaredVariables(node) : [];
  }

  getScope(node) {
    if (node && typeof this.scopeManager?.acquire === "function") {
      return this.scopeManager.acquire(node, true) ?? this.scopeManager.acquire(node, false) ?? this.scopeManager.globalScope ?? null;
    }
    return this.scopeManager?.globalScope ?? null;
  }

  markVariableAsUsed(name, node) {
    return markScopeVariableAsUsed(this.getScope(node), name);
  }

  getDisableDirectives() {
    return this.comments.flatMap((comment) => disableDirectivesFromComment(comment));
  }

  getInlineConfigNodes() {
    return this.comments.filter((comment) => isInlineConfigComment(comment));
  }

  applyInlineConfig() {
    return undefined;
  }

  applyLanguageOptions() {
    return undefined;
  }

  finalize() {
    return undefined;
  }

  traverse() {
    return [];
  }

  isGlobalReference() {
    return false;
  }
}

function sourceLineStartIndices(text) {
  const indices = [0];
  for (let index = 0; index < text.length; index += 1) {
    if (text[index] === "\n") {
      indices.push(index + 1);
    }
  }
  return indices;
}

function expandSourceRange(range, beforeCount, afterCount, textLength) {
  return [
    Math.max(range[0] - beforeCount, 0),
    Math.min(range[1] + afterCount, textLength)
  ];
}

function sourceItemsInRange(items, range) {
  return items.filter((item) => item.range && item.range[0] >= range[0] && item.range[1] <= range[1]);
}

function sourceItemsBefore(items, index) {
  return items.filter((item) => item.range && item.range[1] <= index);
}

function sourceItemsAfter(items, index) {
  return items.filter((item) => item.range && item.range[0] >= index);
}

function sourceItemsBetween(items, start, end) {
  return items.filter((item) => item.range && item.range[0] >= start && item.range[1] <= end);
}

function sourceTokensAndComments(sourceCode) {
  return [...sourceCode.tokens, ...sourceCode.comments].sort((left, right) => (left.range?.[0] ?? 0) - (right.range?.[0] ?? 0));
}

function sourceTokensBetween(sourceCode, left, right, options) {
  return sourceApplyTokenFilter(
    sourceItemsBetween(sourceTokenItems(sourceCode, options), sourceCode.getRange(left)[1], sourceCode.getRange(right)[0]),
    options
  );
}

function sourceTokenItems(sourceCode, options) {
  return options.includeComments ? sourceTokensAndComments(sourceCode) : sourceCode.tokens;
}

function sourceTokenRangeOptions(beforeCount, afterCount) {
  if (beforeCount && typeof beforeCount === "object") {
    return sourceTokenOptions(beforeCount, "count");
  }
  return {
    beforeCount: sourceTokenCount(beforeCount, 0),
    afterCount: sourceTokenCount(afterCount, 0),
    includeComments: false,
    filter: null,
    skip: 0,
    count: null
  };
}

function sourceTokenOptions(optionsOrNumber, numericKey) {
  const options = optionsOrNumber && typeof optionsOrNumber === "object" ? optionsOrNumber : { [numericKey]: optionsOrNumber };
  return {
    beforeCount: sourceTokenCount(options.beforeCount, 0),
    afterCount: sourceTokenCount(options.afterCount, 0),
    includeComments: Boolean(options.includeComments),
    filter: typeof options.filter === "function" ? options.filter : null,
    skip: sourceTokenCount(options.skip, 0),
    count: options.count === undefined ? null : sourceTokenCount(options.count, 1)
  };
}

function sourceTokenCount(value, defaultValue) {
  return Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : defaultValue;
}

function sourceApplyTokenFilter(items, options) {
  return options.filter ? items.filter((item) => options.filter(item)) : items;
}

function sourceForwardToken(items, optionsOrNumber) {
  const options = sourceTokenOptions(optionsOrNumber, "skip");
  return items[options.skip] ?? null;
}

function sourceForwardTokens(items, optionsOrNumber) {
  const options = sourceTokenOptions(optionsOrNumber, "count");
  const start = options.skip;
  const end = options.count === null ? undefined : start + options.count;
  return items.slice(start, end);
}

function sourceBackwardToken(items, optionsOrNumber) {
  const options = sourceTokenOptions(optionsOrNumber, "skip");
  return items.at(-(options.skip + 1)) ?? null;
}

function sourceBackwardTokens(items, optionsOrNumber) {
  const options = sourceTokenOptions(optionsOrNumber, "count");
  if (options.count === 0) {
    return [];
  }
  const end = options.skip === 0 ? undefined : -options.skip;
  const available = end === undefined ? items : items.slice(0, end);
  return options.count === null ? available : available.slice(-options.count);
}

function sourceNodeByRangeIndex(node, index, seen = new Set()) {
  if (!node || typeof node !== "object" || seen.has(node)) {
    return null;
  }
  seen.add(node);
  if (!node.range || index < node.range[0] || index > node.range[1]) {
    return null;
  }
  for (const value of Object.values(node)) {
    const children = Array.isArray(value) ? value : [value];
    for (const child of children) {
      const match = sourceNodeByRangeIndex(child, index, seen);
      if (match) {
        return match;
      }
    }
  }
  return node;
}

function sourceAncestorsForNode(root, target, ancestors = [], seen = new Set()) {
  if (!root || typeof root !== "object" || seen.has(root)) {
    return null;
  }
  if (root === target) {
    return ancestors;
  }
  seen.add(root);

  for (const value of Object.values(root)) {
    const children = Array.isArray(value) ? value : [value];
    for (const child of children) {
      if (!child || typeof child !== "object") {
        continue;
      }
      const result = sourceAncestorsForNode(child, target, [...ancestors, root], seen);
      if (result) {
        return result;
      }
    }
  }
  return null;
}

function markScopeVariableAsUsed(scope, name) {
  let current = scope;
  while (current) {
    const variable = scopeVariableByName(current, name);
    if (variable) {
      variable.eslintUsed = true;
      return true;
    }
    current = current.upper ?? null;
  }
  return false;
}

function scopeVariableByName(scope, name) {
  if (scope?.set instanceof Map && scope.set.has(name)) {
    return scope.set.get(name);
  }
  if (Array.isArray(scope?.variables)) {
    return scope.variables.find((variable) => variable?.name === name) ?? null;
  }
  return null;
}

function isInlineConfigComment(comment) {
  return /^(?:eslint(?:-disable|-enable|-disable-next-line|-disable-line|-env)?|global|globals|exported)(?:\s|$)/u.test(String(comment?.value ?? "").trim());
}

function disableDirectivesFromComment(comment) {
  const match = String(comment?.value ?? "").trim().match(/^(eslint-(?:disable-next-line|disable-line|disable|enable))\b\s*(.*)$/u);
  if (!match) {
    return [];
  }

  const [, type, rawValue] = match;
  const [rawRules, justification = ""] = rawValue.split(/\s--\s/u, 2).map((value) => value.trim());
  const ruleIds = rawRules.split(",").map((ruleId) => ruleId.trim()).filter(Boolean);
  if (ruleIds.length === 0) {
    return [{ type, node: comment, value: null, ruleId: null, justification }];
  }
  return ruleIds.map((ruleId) => ({ type, node: comment, value: ruleId, ruleId, justification }));
}

class RuleTester {
  static get version() {
    return version;
  }

  static setDefaultConfig(config) {
    if (typeof config !== "object" || config === null) {
      throw new TypeError("RuleTester.setDefaultConfig: config must be an object");
    }
    ruleTesterDefaultConfig = config;
    ruleTesterDefaultConfig.rules = ruleTesterDefaultConfig.rules || {};
  }

  static getDefaultConfig() {
    return ruleTesterDefaultConfig;
  }

  static resetDefaultConfig() {
    ruleTesterDefaultConfig = {
      rules: {
        ...RULE_TESTER_INITIAL_CONFIG.rules
      }
    };
  }

  static get describe() {
    return ruleTesterDescribe ?? (typeof globalThis.describe === "function" ? globalThis.describe : ruleTesterDescribeDefaultHandler);
  }

  static set describe(value) {
    ruleTesterDescribe = value;
  }

  static get it() {
    return ruleTesterIt ?? (typeof globalThis.it === "function" ? globalThis.it : ruleTesterItDefaultHandler);
  }

  static set it(value) {
    ruleTesterIt = value;
  }

  static only(item) {
    if (typeof item === "string") {
      return { code: item, only: true };
    }
    return { ...item, only: true };
  }

  static get itOnly() {
    if (typeof ruleTesterItOnly === "function") {
      return ruleTesterItOnly;
    }
    if (typeof ruleTesterIt === "function" && typeof ruleTesterIt.only === "function") {
      return Function.bind.call(ruleTesterIt.only, ruleTesterIt);
    }
    if (typeof globalThis.it === "function" && typeof globalThis.it.only === "function") {
      return Function.bind.call(globalThis.it.only, globalThis.it);
    }
    if (typeof ruleTesterDescribe === "function" || typeof ruleTesterIt === "function") {
      throw new Error("Set `RuleTester.itOnly` to use `only` with a custom test framework.");
    }
    throw new Error("To use `only`, use RuleTester with a test framework that provides `it.only()` like Mocha.");
  }

  static set itOnly(value) {
    ruleTesterItOnly = value;
  }

  constructor(config = {}) {
    this.config = mergeRuleTesterConfig(ruleTesterDefaultConfig, config);
  }

  run(ruleName, rule, tests = {}) {
    const linter = new Linter();
    linter.defineRule(ruleName, rule);
    RuleTester.describe(ruleName, () => {
      RuleTester.describe("valid", () => {
        for (const test of tests.valid ?? []) {
          const testCase = normalizeRuleTesterCase(test);
          RuleTester[testCase.only ? "itOnly" : "it"](testCase.name ?? testCase.code, () => {
            const messages = linter.verify(testCase.code, ruleTesterConfig(ruleName, this.config, testCase, "error"), ruleTesterOptions(testCase));
            if (messages.length > 0) {
              throw new Error(`Should have no errors but had ${messages.length}: ${JSON.stringify(messages)}`);
            }
          });
        }
      });

      RuleTester.describe("invalid", () => {
        for (const test of tests.invalid ?? []) {
          const testCase = normalizeRuleTesterCase(test);
          RuleTester[testCase.only ? "itOnly" : "it"](testCase.name ?? testCase.code, () => {
            const config = ruleTesterConfig(ruleName, this.config, testCase, "error");
            const options = ruleTesterOptions(testCase);
            const result = Object.hasOwn(testCase, "output")
              ? linter.verifyAndFix(testCase.code, config, options)
              : { messages: linter.verify(testCase.code, config, options), output: testCase.code };
            const messages = result.messages;
            assertRuleTesterErrors(testCase, messages, rule);
            assertRuleTesterOutput(testCase, result.output);
          });
        }
      });
    });
  }
}

function ruleTesterDescribeDefaultHandler(_text, method) {
  return method();
}

function ruleTesterItDefaultHandler(_text, method) {
  return method();
}

function mergeRuleTesterConfig(baseConfig, overrideConfig) {
  return {
    ...baseConfig,
    ...overrideConfig,
    rules: {
      ...(baseConfig.rules ?? {}),
      ...(overrideConfig.rules ?? {})
    }
  };
}

function normalizeRuleTesterCase(test) {
  if (typeof test === "string") {
    return { code: test };
  }
  if (!test || typeof test !== "object" || typeof test.code !== "string") {
    throw new TypeError("RuleTester cases must be strings or objects with a code string");
  }
  return test;
}

function ruleTesterConfig(ruleName, baseConfig, testCase, defaultSeverity) {
  return {
    ...baseConfig,
    ...testCase,
    rules: {
      [ruleName]: testCase.options ? [defaultSeverity, ...testCase.options] : defaultSeverity,
      ...(baseConfig.rules ?? {}),
      ...(testCase.rules ?? {})
    }
  };
}

function ruleTesterOptions(testCase) {
  return {
    filename: testCase.filename ?? testCase.filePath ?? "input.js"
  };
}

function assertRuleTesterErrors(testCase, messages, rule) {
  const expected = testCase.errors;
  if (typeof expected === "number") {
    if (messages.length !== expected) {
      throw new Error(`Should have ${expected} error${expected === 1 ? "" : "s"} but had ${messages.length}: ${JSON.stringify(messages)}`);
    }
    return;
  }

  if (!Array.isArray(expected)) {
    if (messages.length === 0) {
      throw new Error("Should have at least one error but had 0: []");
    }
    return;
  }

  if (messages.length !== expected.length) {
    throw new Error(`Should have ${expected.length} error${expected.length === 1 ? "" : "s"} but had ${messages.length}: ${JSON.stringify(messages)}`);
  }

  expected.forEach((expectation, index) => {
    if (typeof expectation === "number") {
      return;
    }
    const message = messages[index];
    for (const property of ["message", "line", "column", "endLine", "endColumn"]) {
      if (expectation[property] != null && message[property] !== expectation[property]) {
        throw new Error(`Error ${index + 1} ${property} should be ${JSON.stringify(expectation[property])} but was ${JSON.stringify(message[property])}`);
      }
    }
    if (expectation.messageId != null) {
      const expectedMessage = ruleTesterMessageForId(rule, expectation.messageId, expectation.data);
      if (message.message !== expectedMessage) {
        throw new Error(`Error ${index + 1} messageId ${JSON.stringify(expectation.messageId)} should resolve to ${JSON.stringify(expectedMessage)} but message was ${JSON.stringify(message.message)}`);
      }
    }
    if (expectation.type != null && message.nodeType !== expectation.type) {
      throw new Error(`Error ${index + 1} type should be ${JSON.stringify(expectation.type)} but was ${JSON.stringify(message.nodeType)}`);
    }
    if (Object.hasOwn(expectation, "suggestions")) {
      assertRuleTesterSuggestions(index, message.suggestions ?? [], expectation.suggestions, testCase.code, rule);
    }
  });
}

function assertRuleTesterSuggestions(errorIndex, actualSuggestions, expectedSuggestions, code, rule) {
  if (expectedSuggestions == null) {
    if (actualSuggestions.length > 0) {
      throw new Error(`Error ${errorIndex + 1} should have no suggestions but had ${actualSuggestions.length}: ${JSON.stringify(actualSuggestions)}`);
    }
    return;
  }
  if (typeof expectedSuggestions === "number") {
    if (actualSuggestions.length !== expectedSuggestions) {
      throw new Error(`Error ${errorIndex + 1} should have ${expectedSuggestions} suggestion${expectedSuggestions === 1 ? "" : "s"} but had ${actualSuggestions.length}: ${JSON.stringify(actualSuggestions)}`);
    }
    return;
  }
  if (!Array.isArray(expectedSuggestions)) {
    throw new TypeError("RuleTester suggestions must be a number, null, or an array");
  }
  if (actualSuggestions.length !== expectedSuggestions.length) {
    throw new Error(`Error ${errorIndex + 1} should have ${expectedSuggestions.length} suggestion${expectedSuggestions.length === 1 ? "" : "s"} but had ${actualSuggestions.length}: ${JSON.stringify(actualSuggestions)}`);
  }

  expectedSuggestions.forEach((expectation, suggestionIndex) => {
    const suggestion = actualSuggestions[suggestionIndex];
    if (expectation.messageId != null) {
      const expectedDesc = ruleTesterMessageForId(rule, expectation.messageId, expectation.data);
      if (suggestion.desc !== expectedDesc) {
        throw new Error(`Error ${errorIndex + 1} suggestion ${suggestionIndex + 1} messageId ${JSON.stringify(expectation.messageId)} should resolve to ${JSON.stringify(expectedDesc)} but desc was ${JSON.stringify(suggestion.desc)}`);
      }
    }
    if (expectation.desc != null && suggestion.desc !== expectation.desc) {
      throw new Error(`Error ${errorIndex + 1} suggestion ${suggestionIndex + 1} desc should be ${JSON.stringify(expectation.desc)} but was ${JSON.stringify(suggestion.desc)}`);
    }
    if (Object.hasOwn(expectation, "output")) {
      const output = applyRuleTesterSuggestionFixes(code, suggestion.fix);
      if (output !== expectation.output) {
        throw new Error(`Error ${errorIndex + 1} suggestion ${suggestionIndex + 1} output should be ${JSON.stringify(expectation.output)} but was ${JSON.stringify(output)}`);
      }
    }
  });
}

function applyRuleTesterSuggestionFixes(code, fix) {
  return applyRuleFixes(code, fix);
}

function applyRuleFixes(code, fix) {
  return ruleFixItems(fix)
    .sort((left, right) => right.range[0] - left.range[0])
    .reduce((output, item) => output.slice(0, item.range[0]) + item.text + output.slice(item.range[1]), code);
}

function ruleFixItems(fix) {
  if (!fix) {
    return [];
  }
  if (Array.isArray(fix)) {
    return fix.flatMap((item) => ruleFixItems(item));
  }
  return fix.range ? [fix] : [];
}

function ruleTesterMessageForId(rule, messageId, data = {}) {
  const template = rule?.meta?.messages?.[messageId];
  if (typeof template !== "string") {
    throw new Error(`RuleTester messageId ${JSON.stringify(messageId)} was not found in rule.meta.messages`);
  }
  return replaceRuleMessageData(template, data);
}

function replaceRuleMessageData(template, data = {}) {
  return template.replace(/\{\{\s*([^{}]+?)\s*\}\}/gu, (placeholder, key) => (
    Object.hasOwn(data, key) ? String(data[key]) : placeholder
  ));
}

function assertRuleTesterOutput(testCase, actualOutput) {
  if (!Object.hasOwn(testCase, "output")) {
    return;
  }
  if (testCase.output == null) {
    return;
  }
  if (testCase.output !== actualOutput) {
    throw new Error(`Output is incorrect. Expected ${JSON.stringify(testCase.output)} but was ${JSON.stringify(actualOutput)}.`);
  }
}

function createLinterSourceCode(text, parser = null, parserOptions = {}) {
  const parsed = parseSourceCode(text, parser, parserOptions);
  if (parsed) {
    return parsed;
  }
  return new SourceCode({
    text,
    ast: {
      type: "Program",
      range: [0, text.length],
      comments: sourceCommentsFromText(text),
      tokens: sourceTokensFromText(text)
    }
  });
}

function parseSourceCode(text, parser, parserOptions) {
  if (!parser) {
    return null;
  }
  if (typeof parser.parseForESLint === "function") {
    const result = parser.parseForESLint(text, parserOptions) ?? {};
    return new SourceCode({
      text,
      ast: result.ast ?? null,
      parserServices: result.services ?? result.parserServices ?? {},
      scopeManager: result.scopeManager ?? null,
      visitorKeys: result.visitorKeys ?? null
    });
  }
  if (typeof parser.parse === "function") {
    return new SourceCode({
      text,
      ast: parser.parse(text, parserOptions)
    });
  }
  return null;
}

function sourceTokensFromText(text) {
  const tokens = [];
  const lineStarts = sourceLineStartIndices(text);
  let index = 0;

  while (index < text.length) {
    const char = text[index];
    const next = text[index + 1];
    if (/\s/u.test(char)) {
      index += 1;
      continue;
    }
    if (char === "/" && next === "/") {
      index += 2;
      while (index < text.length && text[index] !== "\n" && text[index] !== "\r") {
        index += 1;
      }
      continue;
    }
    if (char === "/" && next === "*") {
      const close = text.indexOf("*/", index + 2);
      index = close === -1 ? text.length : close + 2;
      continue;
    }
    if (char === "\"" || char === "'" || char === "`") {
      const start = index;
      const end = skipQuotedSourceText(text, index, char);
      tokens.push(sourceTokenNode("String", text.slice(start, end), start, end, lineStarts));
      index = end;
      continue;
    }
    if (isIdentifierStart(char)) {
      const start = index;
      index += 1;
      while (index < text.length && isIdentifierPart(text[index])) {
        index += 1;
      }
      const value = text.slice(start, index);
      tokens.push(sourceTokenNode(JS_KEYWORDS.has(value) ? "Keyword" : "Identifier", value, start, index, lineStarts));
      continue;
    }
    if (isDigit(char)) {
      const start = index;
      index += 1;
      while (index < text.length && /[0-9._a-fA-FxXbBoO]/u.test(text[index])) {
        index += 1;
      }
      tokens.push(sourceTokenNode("Numeric", text.slice(start, index), start, index, lineStarts));
      continue;
    }
    const punctuator = sourcePunctuatorAt(text, index);
    tokens.push(sourceTokenNode("Punctuator", punctuator, index, index + punctuator.length, lineStarts));
    index += punctuator.length;
  }
  return tokens;
}

function sourceCommentsFromText(text) {
  const comments = [];
  const lineStarts = sourceLineStartIndices(text);
  let index = 0;

  while (index < text.length) {
    const char = text[index];
    const next = text[index + 1];
    if (char === "\"" || char === "'" || char === "`") {
      index = skipQuotedSourceText(text, index, char);
      continue;
    }
    if (char === "/" && next === "/") {
      const start = index;
      const valueStart = index + 2;
      let end = valueStart;
      while (end < text.length && text[end] !== "\n" && text[end] !== "\r") {
        end += 1;
      }
      comments.push(sourceCommentNode("Line", text.slice(valueStart, end), start, end, lineStarts));
      index = end;
      continue;
    }
    if (char === "/" && next === "*") {
      const start = index;
      const valueStart = index + 2;
      const close = text.indexOf("*/", valueStart);
      const valueEnd = close === -1 ? text.length : close;
      const end = close === -1 ? text.length : close + 2;
      comments.push(sourceCommentNode("Block", text.slice(valueStart, valueEnd), start, end, lineStarts));
      index = end;
      continue;
    }
    index += 1;
  }
  return comments;
}

function skipQuotedSourceText(text, start, quote) {
  let index = start + 1;
  while (index < text.length) {
    if (text[index] === "\\") {
      index += 2;
      continue;
    }
    if (text[index] === quote) {
      return index + 1;
    }
    index += 1;
  }
  return text.length;
}

function isIdentifierStart(char) {
  return /[$_\p{ID_Start}]/u.test(char);
}

function isIdentifierPart(char) {
  return /[$_\u200c\u200d\p{ID_Continue}]/u.test(char);
}

function isDigit(char) {
  return /[0-9]/u.test(char);
}

function sourcePunctuatorAt(text, index) {
  const candidates = ["===", "!==", ">>>", "**=", "<<=", ">>=", "=>", "==", "!=", "<=", ">=", "++", "--", "&&", "||", "??", "+=", "-=", "*=", "/=", "%=", "**", "<<", ">>", "?.", "..."];
  return candidates.find((candidate) => text.startsWith(candidate, index)) ?? text[index];
}

function sourceTokenNode(type, value, start, end, lineStarts) {
  return {
    type,
    value,
    range: [start, end],
    loc: {
      start: sourceLocFromIndex(lineStarts, start),
      end: sourceLocFromIndex(lineStarts, end)
    }
  };
}

function sourceCommentNode(type, value, start, end, lineStarts) {
  return {
    type,
    value,
    range: [start, end],
    loc: {
      start: sourceLocFromIndex(lineStarts, start),
      end: sourceLocFromIndex(lineStarts, end)
    }
  };
}

function sourceLocFromIndex(lineStarts, index) {
  let line = 0;
  while (line + 1 < lineStarts.length && lineStarts[line + 1] <= index) {
    line += 1;
  }
  return {
    line: line + 1,
    column: index - lineStarts[line]
  };
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
  const filterUnconfiguredRules = hasRuleConfigSource(options);
  return (diagnostics ?? []).flatMap((diagnostic) => {
    if (!diagnostic?.ruleId) {
      return [diagnostic];
    }
    if (diagnostic.ruleId === "io") {
      return [diagnostic];
    }

    const filePath = normalizeESLintFilePath(diagnostic.filePath, options.cwd);
    const ruleSeverities = ruleSeverityMapForOptions(options, filePath);
    const severity = ruleSeverities?.get(diagnostic.ruleId);
    if (filterUnconfiguredRules && !ruleSeverities?.has(diagnostic.ruleId)) {
      return [];
    }
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

function hasRuleConfigSource(options = {}) {
  if (options.noConfig || options.baseConfig || options.overrideConfig || options.rules) {
    return true;
  }
  return !options.noConfig && Boolean(configPathForOptions(options));
}

function exitCodeForDiagnostics(diagnostics) {
  return (diagnostics?.length ?? 0) > 0 ? 1 : 0;
}

function throwOnUnmatchedPatternDiagnostics(report, options = {}) {
  if (options.errorOnUnmatchedPattern === false) {
    return;
  }
  const diagnostic = (report.diagnostics ?? []).find((item) => item?.ruleId === "io" && /unable to stat path/i.test(item.message ?? ""));
  if (diagnostic) {
    throw new Error(`No files matching '${unmatchedPatternDisplayPath(diagnostic.filePath, options.cwd)}' were found.`);
  }
}

function unmatchedPatternDisplayPath(filePath, cwd) {
  const root = resolvePath(cwd ?? process.cwd());
  if (typeof filePath === "string" && filePath.startsWith(`${root}/`)) {
    return filePath.slice(root.length + 1);
  }
  return filePath;
}

function normalizeESLintFilePath(filePath, cwd) {
  if (filePath === "<text>") return filePath;
  if (isAbsolute(filePath)) return filePath;
  return resolvePath(cwd ?? process.cwd(), filePath);
}

function textFilePathForOptions(options = {}, fallback) {
  return options.filePath ?? options.filename ?? fallback;
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
  const patterns = ignoreDisabled(options) ? [] : ignorePatternsForOptions(options, cwd);
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
  if (ignoreDisabled(options) || options.warnIgnored === false) {
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
  if (ignoreDisabled(options)) {
    return false;
  }

  const cwd = options.cwd ?? process.cwd();
  const normalized = normalizeIgnoredPath(filePath, cwd);
  const patterns = ignorePatternsForOptions(options, cwd, filePath);
  return pathIgnoredByPatterns(normalized, patterns);
}

function ignoreDisabled(options = {}) {
  return options.noIgnore || options.ignore === false;
}

function ignorePatternsForOptions(options, cwd, filePath) {
  const patterns = [];
  for (const pattern of normalizeIgnorePatterns(options.ignorePatterns)) {
    patterns.push(pattern);
  }
  patterns.push(...ignorePatternsFromConfig(options.baseConfig));

  const ignorePath = options.ignorePath ?? ".eslintignore";
  if (ignorePath) {
    patterns.push(...readIgnoreFile(resolvePath(cwd, ignorePath)));
  }
  patterns.push(...ignorePatternsFromFileConfig(options, filePath));
  patterns.push(...ignorePatternsFromConfig(options.overrideConfig));
  return patterns;
}

function ignorePatternsFromFileConfig(options, filePath) {
  if (options.noConfig) {
    return [];
  }

  const configPath = filePath ? configPathForFile(options, filePath) : configPathForOptions(options);
  if (!configPath) {
    return [];
  }

  return ignorePatternsFromConfig(readConfig(configPath, options.cwd));
}

function ignorePatternsFromConfig(config) {
  if (!config) {
    return [];
  }
  if (Array.isArray(config)) {
    return config.flatMap((entry) => ignorePatternsFromConfig(entry));
  }

  const flatConfigIgnores = config.files ? [] : normalizeIgnorePatterns(config.ignores);
  return [
    ...normalizeIgnorePatterns(config.ignorePatterns),
    ...flatConfigIgnores
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

function matchesConfigFilePattern(target, pattern) {
  const expression = new RegExp(`^${globPatternRegExpSource(pattern)}$`);
  return expression.test(target);
}

function hasGlobSyntax(pattern) {
  return /[*?[\]{}]/.test(pattern);
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

function createBuiltinRule(ruleId) {
  return {
    meta: ruleMetaForRuleId(ruleId),
    create() {
      return {};
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
  result.fixableErrorCount = 0;
  result.fixableWarningCount = 0;
  for (const message of result.messages) {
    if (message.severity === 2) {
      result.errorCount += 1;
      if (ruleFixItems(message.fix).length > 0) {
        result.fixableErrorCount += 1;
      }
    } else {
      result.warningCount += 1;
      if (ruleFixItems(message.fix).length > 0) {
        result.fixableWarningCount += 1;
      }
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

function formatResultsByName(input, name = "stylish", metadata = {}) {
  const results = formatterResults(input);
  if (name === "json") {
    return JSON.stringify(input);
  }
  if (name === "json-with-metadata") {
    return JSON.stringify({
      results,
      metadata: {
        rulesMeta: typeof metadata.rulesMeta === "function" ? metadata.rulesMeta(results) : rulesMetaForResults(results)
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

function formatterResults(input) {
  if (Array.isArray(input)) {
    return input;
  }
  if (input && typeof input === "object" && Array.isArray(input.results)) {
    return input.results;
  }
  if (input && typeof input === "object" && Array.isArray(input.diagnostics)) {
    return reportToESLintResults(input, {
      filePaths: (input.filePaths ?? []).map((filePath) => normalizeESLintFilePath(filePath))
    });
  }
  throw new Error("'results' must be an array or lint report");
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

function rulesMetaForResults(results, ruleMetaForMessage) {
  if (!Array.isArray(results)) {
    throw new Error("'results' must be an array");
  }

  const meta = {};
  for (const result of results) {
    for (const message of [...(result.messages ?? []), ...(result.suppressedMessages ?? [])]) {
      if (message.ruleId) {
        meta[message.ruleId] = ruleMetaForMessage?.(message.ruleId, result, message) ?? ruleMetaForRuleId(message.ruleId);
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
  Linter,
  RuleTester,
  SourceCode,
  UtooLint,
  default: UtooLint,
  lintFiles,
  lintText,
  loadESLint,
  platformPackageName,
  resolveBinary,
  run,
  runFishlint,
  translateFishlintArgs,
  version
};
