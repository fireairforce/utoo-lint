import type { ConfigObject } from "./index.js";

export function defineConfig(...configs: Array<ConfigObject | ConfigObject[]>): ConfigObject[];
export function globalIgnores(ignorePatterns: string[], name?: string): ConfigObject;
