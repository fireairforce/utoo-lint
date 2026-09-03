import { spawnSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import { dirname, extname, resolve as resolvePath } from "node:path";
import { fileURLToPath } from "node:url";

export const CONFIG_FILENAMES = [
  "utlint.config.ts",
  "utlint.config.json",
  "utoo.json",
  "utoo-lint.json"
];

const TYPESCRIPT_CONFIG_EXTENSIONS = new Set([".ts", ".mts", ".cts"]);
const JAVASCRIPT_CONFIG_EXTENSIONS = new Set([".js", ".mjs", ".cjs"]);
const loaderPath = fileURLToPath(new URL("./load-config.js", import.meta.url));

export function findConfigPath(directory, cache) {
  let current = resolvePath(directory);
  const visited = [];
  while (true) {
    if (cache?.has(current)) {
      return cacheConfigPath(cache, visited, cache.get(current));
    }

    visited.push(current);
    for (const filename of CONFIG_FILENAMES) {
      const candidate = resolvePath(current, filename);
      if (isFile(candidate)) {
        return cacheConfigPath(cache, visited, candidate);
      }
    }
    const parent = dirname(current);
    if (parent === current) {
      return cacheConfigPath(cache, visited, undefined);
    }
    current = parent;
  }
}

function cacheConfigPath(cache, directories, configPath) {
  for (const directory of directories) {
    cache?.set(directory, configPath);
  }
  return configPath;
}

function isFile(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

export function readConfig(path, cwd, cache) {
  const configPath = resolvePath(cwd ?? process.cwd(), path);
  if (cache?.has(configPath)) {
    return cache.get(configPath);
  }

  let config;
  if (isExecutableConfigPath(configPath)) {
    config = readExecutableConfig(configPath, cwd);
  } else {
    try {
      config = JSON.parse(readFileSync(configPath, "utf8"));
    } catch (error) {
      throw configReadError(configPath, error.message);
    }
  }

  cache?.set(configPath, config);
  return config;
}

export function isExecutableConfigPath(path) {
  const extension = extname(path);
  return TYPESCRIPT_CONFIG_EXTENSIONS.has(extension) || JAVASCRIPT_CONFIG_EXTENSIONS.has(extension);
}

function readExecutableConfig(path, cwd) {
  const result = spawnSync(process.execPath, [loaderPath, path], {
    cwd: cwd ?? process.cwd(),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe", "pipe"]
  });
  if (result.error) {
    throw configReadError(path, result.error.message);
  }
  if (result.status !== 0) {
    throw configReadError(path, (result.stderr ?? "").trim() || "config loader failed");
  }
  try {
    return JSON.parse(result.output?.[3] ?? "");
  } catch (error) {
    throw configReadError(path, error.message);
  }
}

function configReadError(path, message) {
  return new Error(`utoo-lint unable to read config ${path}: ${message}`);
}
