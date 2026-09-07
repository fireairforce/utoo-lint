const { createRequire } = require("node:module");
const { dirname, join, resolve } = require("node:path");

// The same reviewed aliases used by the ESLint config migrator.
const RULE_ALIASES = new Map([
  ["no-native-reassign", "no-global-assign"],
  ["@typescript-eslint/no-invalid-this", "no-invalid-this"]
]);

// Resolve configuration only. Parsing, rule execution, and fixes stay native.
function createLegacyConfigResolver(cwd, { ignorePath, ignorePatterns, configFile, useEslintrc = true } = {}) {
  const resolvedIgnorePath = ignorePath ? resolve(cwd, ignorePath) : undefined;
  const resolvedConfigFile = configFile ? resolve(cwd, configFile) : undefined;
  const projectRequire = createRequire(join(cwd, "package.json"));
  let eslintPackage;
  try {
    eslintPackage = projectRequire.resolve("eslint/package.json");
  } catch (error) {
    if (error.code !== "MODULE_NOT_FOUND") throw error;
  }

  let load;
  if (eslintPackage) {
    const manifest = projectRequire(eslintPackage);
    // Some shared configs patch ESLint's module-resolution internals. Use their
    // own ESLint 8 config resolver when installed, and never recurse into an
    // eslint package alias that points back to @utoo/lint.
    const major = Number(manifest.version.split(".")[0]);
    if (manifest.name === "eslint" && major === 8) {
      const { CLIEngine } = projectRequire(join(dirname(eslintPackage), "lib/cli-engine/cli-engine.js"));
      const engine = new CLIEngine({ cwd, ignorePath: resolvedIgnorePath, ignorePattern: ignorePatterns, configFile: resolvedConfigFile, useEslintrc });
      load = (filePath) => {
        try {
          return { ...engine.getConfigForFile(filePath), isIgnored: (path) => engine.isPathIgnored(path) };
        } catch (error) {
          if (error.messageTemplate === "no-config-found") return undefined;
          throw error;
        }
      };
    }
  }

  if (!load) {
    const { Legacy } = require("@eslint/eslintrc");
    const eslintJs = require("@eslint/js");
    const factory = new Legacy.CascadingConfigArrayFactory({
      cwd,
      specificConfigPath: resolvedConfigFile,
      useEslintrc,
      ignorePath: resolvedIgnorePath,
      cliConfig: ignorePatterns?.length ? { ignorePatterns } : undefined,
      getEslintRecommendedConfig: () => eslintJs.configs.recommended,
      getEslintAllConfig: () => eslintJs.configs.all
    });
    load = (filePath) => {
      const configs = factory.getConfigArrayForFile(filePath, { ignoreNotFoundError: true });
      if (!configs.some((entry) => entry.type === "config" && entry.filePath)) return undefined;
      const config = configs.extractConfig(filePath);
      return { ...config.toCompatibleObjectAsConfigFileContent(), isIgnored: config.ignores };
    };
  }

  const configs = new Map();
  return (filePath) => {
    if (!configs.has(filePath)) {
      const config = load(filePath);
      if (config) {
        config.rules = Object.fromEntries(Object.entries(config.rules).map(([rule, value]) => [RULE_ALIASES.get(rule) ?? rule, value]));
      }
      configs.set(filePath, config);
    }
    return configs.get(filePath);
  };
}

module.exports = { createLegacyConfigResolver };
