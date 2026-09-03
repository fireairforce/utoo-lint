import assert from "node:assert/strict";
import fs, { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { createRequire, syncBuiltinESMExports } from "node:module";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { ESLint, lintFiles, resolveBinary } from "../index.js";
import { CONFIG_FILENAMES, findConfigPath } from "../lib/config-loader.js";

const require = createRequire(import.meta.url);
const { findConfigPath: findCommonJSConfigPath } = require("../lib/config-loader.cjs");
const packageDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const builtBinary = resolve(
  packageDirectory,
  "..",
  "..",
  "zig-out",
  "bin",
  process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint"
);

function testBinary() {
  return fs.existsSync(builtBinary) ? builtBinary : resolveBinary();
}

function createProject(t) {
  const project = mkdtempSync(join(tmpdir(), "utoo-lint-config-discovery-"));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  return project;
}

function write(path, source = "{}\n") {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, source);
  return path;
}

function countConfigStatCalls(callback) {
  const originalStatSync = fs.statSync;
  let count = 0;
  fs.statSync = (path, ...args) => {
    if (CONFIG_FILENAMES.includes(basename(path))) {
      count += 1;
    }
    return originalStatSync(path, ...args);
  };
  syncBuiltinESMExports();

  try {
    const value = callback();
    return { count, value };
  } finally {
    fs.statSync = originalStatSync;
    syncBuiltinESMExports();
  }
}

for (const [format, findConfig] of [
  ["ESM", findConfigPath],
  ["CommonJS", findCommonJSConfigPath]
]) {
  test(`${format} config discovery memoizes hits for visited and sibling directories`, (t) => {
    const project = createProject(t);
    const firstDirectory = join(project, "packages", "first", "src");
    const siblingDirectory = join(project, "packages", "second", "src");
    mkdirSync(firstDirectory, { recursive: true });
    mkdirSync(siblingDirectory, { recursive: true });
    const configPath = write(join(project, "utlint.config.json"));
    const cache = new Map();

    assert.equal(findConfig(firstDirectory, cache), configPath);
    for (const directory of [
      firstDirectory,
      dirname(firstDirectory),
      join(project, "packages"),
      project
    ]) {
      assert.equal(cache.get(directory), configPath, directory);
    }

    rmSync(configPath);
    assert.equal(findConfig(siblingDirectory, cache), configPath);
    assert.equal(cache.get(siblingDirectory), configPath);
    assert.equal(findConfig(siblingDirectory, new Map()), undefined);
  });

  test(`${format} config discovery memoizes negative ancestor results`, (t) => {
    const project = createProject(t);
    const firstDirectory = join(project, "packages", "first", "src");
    const siblingDirectory = join(project, "packages", "second", "src");
    mkdirSync(firstDirectory, { recursive: true });
    mkdirSync(siblingDirectory, { recursive: true });
    const cache = new Map();

    assert.equal(findConfig(firstDirectory, cache), undefined);
    assert.equal(cache.has(firstDirectory), true);
    assert.equal(cache.has(join(project, "packages")), true);
    const configPath = write(join(project, "utlint.config.ts"), "export default {};\n");

    assert.equal(findConfig(siblingDirectory, cache), undefined);
    assert.equal(cache.has(siblingDirectory), true);
    assert.equal(findConfig(siblingDirectory, new Map()), configPath);
  });
}

test("cached config discovery preserves nearest-directory and filename precedence", (t) => {
  const project = createProject(t);
  const rootJson = write(join(project, "utlint.config.json"));
  const rootTypeScript = write(join(project, "utlint.config.ts"), "export default {};\n");
  const nestedDirectory = join(project, "packages", "app", "src");
  const nestedConfig = write(join(project, "packages", "app", "utoo-lint.json"));
  mkdirSync(nestedDirectory, { recursive: true });

  assert.equal(findConfigPath(project, new Map()), rootTypeScript);
  assert.notEqual(rootJson, rootTypeScript);
  assert.equal(findConfigPath(nestedDirectory, new Map()), nestedConfig);
});

test("one lint invocation discovers a shared config only once", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    'export default { rules: { "no-debugger": "off" } };\n'
  );
  const firstSource = write(join(project, "src", "first.js"), "debugger;\n");
  const secondSource = write(join(project, "src", "second.js"), "debugger;\n");
  const options = { binary: testBinary(), cwd: project };

  const first = countConfigStatCalls(() => lintFiles([firstSource, secondSource], options));
  const second = countConfigStatCalls(() => lintFiles([firstSource, secondSource], options));

  assert.equal(first.value.files, 2);
  assert.equal(second.value.files, 2);
  assert.equal(first.count, CONFIG_FILENAMES.length + 1);
  assert.equal(second.count, CONFIG_FILENAMES.length + 1);
});

test("separate public config lookups observe config changes", async (t) => {
  const project = createProject(t);
  const editorDirectory = join(project, "packages", "editor", "src");
  mkdirSync(editorDirectory, { recursive: true });
  const nonexistentEditorFile = join(editorDirectory, "unsaved.ts");
  const eslint = new ESLint({ cwd: project });

  assert.equal(await eslint.findConfigFile(nonexistentEditorFile), undefined);
  const configPath = write(join(project, "utlint.config.json"));
  assert.equal(await eslint.findConfigFile(nonexistentEditorFile), configPath);
  rmSync(configPath);
  assert.equal(await eslint.findConfigFile(nonexistentEditorFile), undefined);
});

test("explicit and disabled config options bypass automatic discovery", async (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.ts"), "export default {};\n");
  const explicitConfig = write(join(project, "configs", "explicit.json"));
  const sourcePath = join(project, "src", "unsaved.ts");

  const explicit = new ESLint({ cwd: project, overrideConfigFile: explicitConfig });
  assert.equal(await explicit.findConfigFile(sourcePath), explicitConfig);

  const disabled = new ESLint({ cwd: project, overrideConfigFile: true });
  assert.equal(await disabled.findConfigFile(sourcePath), undefined);
});
