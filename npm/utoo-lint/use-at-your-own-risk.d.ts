import { CLIEngine, Linter, UtooLint } from "./index.js";

export const builtinRules: Map<string, unknown>;
export const FlatESLint: typeof UtooLint;
export const LegacyESLint: typeof UtooLint;

export function shouldUseFlatConfig(): Promise<boolean>;

export class FileEnumerator {
  constructor(options?: ConstructorParameters<typeof CLIEngine>[0]);
  iterateFiles(patterns?: string | string[]): Array<{ filePath: string }>;
}
