const { CLIEngine, Linter, UtooLint } = require("./index.cjs");

const builtinRules = new Linter().getRules();
const FlatESLint = UtooLint;
const LegacyESLint = UtooLint;

async function shouldUseFlatConfig() {
  return true;
}

class FileEnumerator {
  constructor(options = {}) {
    this.options = { ...options };
  }

  iterateFiles(patterns = []) {
    const cli = new CLIEngine(this.options);
    return cli.resolveFileGlobPatterns(patterns).map((filePath) => ({ filePath }));
  }
}

module.exports = {
  builtinRules,
  FileEnumerator,
  FlatESLint,
  LegacyESLint,
  shouldUseFlatConfig
};
