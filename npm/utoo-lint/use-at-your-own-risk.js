import { CLIEngine, Linter, UtooLint } from "./index.js";

export const builtinRules = new Linter().getRules();
export const FlatESLint = UtooLint;
export const LegacyESLint = UtooLint;

export async function shouldUseFlatConfig() {
  return true;
}

export class FileEnumerator {
  constructor(options = {}) {
    this.options = { ...options };
  }

  iterateFiles(patterns = []) {
    const cli = new CLIEngine(this.options);
    return cli.resolveFileGlobPatterns(patterns).map((filePath) => ({ filePath }));
  }
}
