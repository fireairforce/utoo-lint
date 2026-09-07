import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { CLIEngine, ESLint, lintText } from "../index.js";

const require = createRequire(import.meta.url);
const { CLIEngine: CommonJSCLIEngine, ESLint: CommonJSESLint } = require("../index.cjs");

process.env.UTOO_LINT_BIN ??= fileURLToPath(new URL(
  `../../../zig-out/bin/utoo-lint${process.platform === "win32" ? ".exe" : ""}`,
  import.meta.url
));

function project(t) {
  const cwd = mkdtempSync(join(tmpdir(), "utoo-lint-legacy-config-"));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  return cwd;
}

function write(path, source) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, source);
  return path;
}

test("ESLint compatibility APIs load project eslintrc rules above baseConfig", (t) => {
  const cwd = project(t);
  write(join(cwd, ".eslintrc.cjs"), 'module.exports = { root: true, rules: { "no-alert": 2, "no-debugger": 0 } };');
  const file = write(join(cwd, "src", "index.js"), "alert('message'); debugger;\n");

  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const engine = new Engine({ cwd, baseConfig: { rules: { "no-debugger": 2 } } });
    const config = engine.getConfigForFile(file);
    assert.deepEqual(config.rules["no-alert"], [2]);
    assert.deepEqual(config.rules["no-debugger"], [0]);
    const report = engine.executeOnFiles([file]);
    assert.equal(report.errorCount, 1);
    assert.deepEqual(report.results.flatMap((r) => r.messages.map((m) => m.ruleId)), ["no-alert"]);
  }
});

test("legacy extends and overrides apply to the requested filename, including editor text", async (t) => {
  const cwd = project(t);
  write(join(cwd, "preset.cjs"), 'module.exports = { rules: { "no-alert": 2, "no-debugger": 2 } };');
  write(join(cwd, ".eslintrc.cjs"), `module.exports = {
    root: true, extends: "./preset.cjs",
    overrides: [{ files: ["*.test.js"], rules: { "no-alert": 0 } }]
  };`);
  const regular = write(join(cwd, "src", "index.js"), "alert('message'); debugger;");
  const testFile = write(join(cwd, "src", "index.test.js"), "alert('message'); debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const engine = new Engine({ cwd, baseConfig: [{ rules: { "no-alert": 1 } }] });
    assert.equal(engine.executeOnFiles([regular]).errorCount, 2);
    assert.equal(engine.executeOnFiles([testFile]).errorCount, 1);
    assert.equal(engine.executeOnText("alert('message'); debugger;", testFile).errorCount, 1);
    const overridden = new Engine({ cwd, overrideConfig: { rules: { "no-debugger": 0 } } });
    assert.equal(overridden.executeOnFiles([testFile]).errorCount, 0);
  }
  const eslint = new ESLint({ cwd });
  assert.deepEqual((await eslint.calculateConfigForFile(testFile)).rules["no-alert"], [0]);
  assert.equal((await eslint.lintText("alert('message'); debugger;", { filePath: testFile }))[0].errorCount, 1);
});

test("legacy cascades respect nested configs, root boundaries, and ignored files", (t) => {
  const parent = project(t);
  write(join(parent, ".eslintrc.json"), JSON.stringify({ rules: { "no-alert": 2 } }));
  const cwd = join(parent, "app");
  write(join(cwd, ".eslintrc.json"), JSON.stringify({ root: true, ignorePatterns: ["generated/"], rules: { "no-debugger": 2 } }));
  write(join(cwd, "src", ".eslintrc.json"), JSON.stringify({ rules: { "no-debugger": 0 } }));
  const rootFile = write(join(cwd, "index.js"), "alert('message'); debugger;");
  const nestedFile = write(join(cwd, "src", "index.js"), "alert('message'); debugger;");
  const ignoredFile = write(join(cwd, "generated", "index.js"), "debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const engine = new Engine({ cwd });
    assert.equal(engine.executeOnFiles([rootFile, nestedFile]).errorCount, 1);
    assert.equal(engine.isPathIgnored(ignoredFile), true);
    assert.equal(engine.executeOnFiles(["."]).errorCount, 1);
    assert.equal(engine.executeOnText("debugger;", ignoredFile).errorCount, 0);
    assert.equal(new Engine({ cwd, ignore: false }).executeOnFiles([ignoredFile]).errorCount, 1);
  }
});

test("legacy discovery observes edits and opt-outs without changing the native APIs", (t) => {
  const cwd = project(t);
  const configFile = write(join(cwd, ".eslintrc.cjs"), 'module.exports = { root: true, rules: { "no-debugger": 2 } };');
  const file = write(join(cwd, "index.js"), "debugger;");
  const engine = new CLIEngine({ cwd });
  assert.equal(engine.executeOnFiles([file]).errorCount, 1);
  write(configFile, 'module.exports = { root: true, rules: { "no-debugger": 0 } };');
  assert.equal(engine.executeOnFiles([file]).errorCount, 0);
  assert.deepEqual(engine.getConfigForFile(file).rules["no-debugger"], [0]);

  write(configFile, 'throw new Error("legacy config must not load");');
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const disabled = new Engine({ cwd, useEslintrc: false, baseConfig: { rules: { "no-debugger": 2 } } });
    assert.equal(disabled.executeOnFiles([file]).errorCount, 1);
  }
  assert.equal(lintText("debugger;", { cwd, filePath: file, overrideConfig: { rules: { "no-debugger": 2 } } }).diagnostics.length, 1);
  write(join(cwd, "utlint.config.json"), JSON.stringify({ rules: { "no-debugger": "off" } }));
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    assert.equal(new Engine({ cwd }).executeOnFiles([file]).errorCount, 0);
  }
});

test("legacy rule aliases reach their native equivalents without dropping unsupported enabled rules", (t) => {
  const cwd = project(t);
  const configFile = write(join(cwd, ".eslintrc.json"), JSON.stringify({
    root: true, rules: { "no-native-reassign": 2 }
  }));
  const file = write(join(cwd, "index.js"), "Object = 1;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const report = new Engine({ cwd }).executeOnFiles([file]);
    assert.equal(report.errorCount, 1);
    assert.equal(report.results[0].messages[0].ruleId, "no-global-assign");
  }
  write(configFile, JSON.stringify({ root: true, rules: { "unsupported-rule-for-test": 2 } }));
  assert.throws(() => new CLIEngine({ cwd }).executeOnFiles([file]), /unknown rule|unsupported-rule-for-test/);
  write(configFile, JSON.stringify({ root: true, rules: { "unsupported-rule-for-test": 0, "no-global-assign": [2, { exceptions: ["Object"] }] } }));
  assert.equal(new CLIEngine({ cwd }).executeOnFiles([file]).errorCount, 0);
});

test("package.json eslintConfig works when eslint is aliased to utoo-lint", (t) => {
  const cwd = project(t);
  write(join(cwd, "package.json"), JSON.stringify({ eslintConfig: { root: true, rules: { "no-debugger": 2 } } }));
  mkdirSync(join(cwd, "node_modules"));
  symlinkSync(fileURLToPath(new URL("..", import.meta.url)), join(cwd, "node_modules", "eslint"), "junction");
  const file = write(join(cwd, "index.js"), "debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    assert.equal(new Engine({ cwd }).executeOnFiles([file]).errorCount, 1);
  }
});

test("CLI ignore options override legacy ignores and replace the default ignore file", (t) => {
  const cwd = project(t);
  write(join(cwd, ".eslintrc.json"), JSON.stringify({ root: true, ignorePatterns: ["generated/*"], rules: { "no-debugger": 2 } }));
  write(join(cwd, ".eslintignore"), "default.js\n");
  write(join(cwd, "custom.ignore"), "custom.js\n");
  const file = write(join(cwd, "generated", "keep.js"), "debugger;");
  const defaultFile = write(join(cwd, "default.js"), "debugger;");
  const customFile = write(join(cwd, "custom.js"), "debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const engine = new Engine({ cwd, ignorePath: "custom.ignore", ignorePatterns: ["!generated/keep.js"] });
    assert.equal(engine.isPathIgnored(file), false);
    assert.equal(engine.isPathIgnored(defaultFile), false);
    assert.equal(engine.isPathIgnored(customFile), true);
    assert.equal(engine.executeOnFiles(["."]).errorCount, 2);
  }
});

test("explicit eslintrc files resolve extends even with automatic discovery disabled", (t) => {
  const cwd = project(t);
  write(join(cwd, ".eslintrc.json"), JSON.stringify({ root: true, rules: { "no-debugger": 2 } }));
  write(join(cwd, "configs", "preset.cjs"), 'module.exports = { rules: { "no-alert": 2 } };');
  write(join(cwd, "configs", ".eslintrc.cjs"), 'module.exports = { extends: "./preset.cjs" };');
  const file = write(join(cwd, "index.js"), "alert('message'); debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    const engine = new Engine({ cwd, configFile: "configs/.eslintrc.cjs", useEslintrc: false });
    assert.deepEqual(engine.getConfigForFile(file).rules["no-alert"], [2]);
    assert.equal(engine.getConfigForFile(file).rules["no-debugger"], undefined);
    assert.equal(engine.executeOnFiles([file]).errorCount, 1);
  }
});

test("CLIEngine configFile loads arbitrary legacy filenames with or without discovery", (t) => {
  const cwd = project(t);
  write(join(cwd, ".eslintrc.json"), JSON.stringify({ root: true, rules: { "no-debugger": 2 } }));
  write(join(cwd, "configs", "preset.cjs"), 'module.exports = { rules: { "no-alert": 2 } };');
  write(join(cwd, "configs", "lint.cjs"), 'module.exports = { extends: "./preset.cjs" };');
  const file = write(join(cwd, "index.js"), "alert('message'); debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    for (const useEslintrc of [false, true]) {
      const engine = new Engine({ cwd, configFile: "configs/lint.cjs", useEslintrc });
      assert.deepEqual(engine.getConfigForFile(file).rules["no-alert"], [2]);
      assert.equal(engine.executeOnFiles([file]).errorCount, useEslintrc ? 2 : 1);
      assert.equal(engine.executeOnText("alert('message'); debugger;", file).errorCount, useEslintrc ? 2 : 1);
    }
  }
});

test("findConfigFile returns the explicit legacy path even with discovery disabled", async (t) => {
  const cwd = project(t);
  write(join(cwd, "utlint.config.json"), JSON.stringify({ rules: { "no-debugger": "off" } }));
  const file = write(join(cwd, "src", "index.js"), "debugger;");
  for (const filename of ["configs/lint.cjs", "configs/.eslintrc.cjs"]) {
    write(join(cwd, filename), 'module.exports = { rules: { "no-debugger": 2 } };');
  }
  for (const Engine of [ESLint, CommonJSESLint]) {
    for (const explicit of [
      { configFile: "configs/lint.cjs" },
      { overrideConfigFile: "configs/.eslintrc.cjs" },
    ]) {
      for (const useEslintrc of [false, true]) {
        const engine = new Engine({ cwd, ...explicit, useEslintrc });
        const expected = join(cwd, explicit.configFile ?? explicit.overrideConfigFile);
        assert.equal(await engine.findConfigFile(), expected);
        assert.equal(await engine.findConfigFile(file), expected);
        assert.deepEqual((await engine.calculateConfigForFile(file)).rules["no-debugger"], [2]);
        assert.equal((await engine.lintText("debugger;", { filePath: file }))[0].errorCount, 1);
      }
    }
  }
});

test("explicit native config options keep precedence over legacy configFile", (t) => {
  const cwd = project(t);
  write(join(cwd, "legacy.cjs"), 'throw new Error("superseded legacy config must not load");');
  write(join(cwd, "native.json"), JSON.stringify({ rules: { "no-debugger": "error" } }));
  write(join(cwd, "override.json"), JSON.stringify({ rules: { "no-alert": "error" } }));
  const file = write(join(cwd, "index.js"), "alert('message'); debugger;");
  for (const Engine of [CLIEngine, CommonJSCLIEngine]) {
    for (const options of [
      { config: "native.json", expected: "no-debugger" },
      { overrideConfigFile: "override.json", expected: "no-alert" },
      { config: "native.json", overrideConfigFile: "override.json", expected: "no-alert" },
    ]) {
      const { expected, ...configOptions } = options;
      const engine = new Engine({ cwd, configFile: "legacy.cjs", ...configOptions });
      assert.deepEqual(engine.executeOnFiles([file]).results[0].messages.map((message) => message.ruleId), [expected]);
    }
  }
});
