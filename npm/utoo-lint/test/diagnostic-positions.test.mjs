import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import * as esm from "../index.js";

const require = createRequire(import.meta.url);
const commonJS = require("../index.cjs");
const binary = fileURLToPath(new URL(
  `../../../zig-out/bin/utoo-lint${process.platform === "win32" ? ".exe" : ""}`,
  import.meta.url,
));

function position(message) {
  return {
    line: message.line,
    column: message.column,
    endLine: message.endLine,
    endColumn: message.endColumn,
  };
}

test("native diagnostics and ESLint APIs expose exclusive end positions", async () => {
  const source = "debugger;";
  const expected = { line: 1, column: 1, endLine: 1, endColumn: 10 };
  for (const api of [esm, commonJS]) {
    const report = api.lintText(source, { binary, noConfig: true, rules: ["no-debugger"], filePath: "fixture.js" });
    assert.equal(report.diagnostics.length, 1);
    assert.deepEqual(position(report.diagnostics[0]), expected);

    const options = { binary, useEslintrc: false, baseConfig: { rules: { "no-debugger": "error" } } };
    const cliResult = new api.CLIEngine(options).executeOnText(source, "fixture.js").results[0];
    assert.deepEqual(position(cliResult.messages[0]), expected);
    const [result] = await new api.ESLint(options).lintText(source, { filePath: "fixture.js" });
    assert.deepEqual(position(result.messages[0]), expected);
  }
});

test("diagnostic ranges use UTF-16 columns and all JavaScript line terminators", async (t) => {
  const comment = "/* 中文😀 */ ";
  const cases = [
    {
      name: "UTF-16 columns",
      code: `${comment}debugger;`,
      rule: "no-debugger",
      expected: { line: 1, column: comment.length + 1, endLine: 1, endColumn: comment.length + 10 },
    },
    {
      name: "UTF-16 within the reported span",
      code: 'alert("中文😀");',
      rule: "no-alert",
      expected: { line: 1, column: 1, endLine: 1, endColumn: 'alert("中文😀")'.length + 1 },
    },
    ...["\n", "\r\n", "\r", "\u2028", "\u2029"].map((newline) => ({
      name: `multiline ${JSON.stringify(newline)}`,
      code: [comment, "alert(", '"好😀"', ");"].join(newline),
      rule: "no-alert",
      expected: { line: 2, column: 1, endLine: 4, endColumn: 2 },
    })),
  ];
  for (const { name, code, rule, expected } of cases) {
    await t.test(name, () => {
      for (const api of [esm, commonJS]) {
        const report = api.lintText(code, { binary, noConfig: true, rules: [rule] });
        assert.equal(report.diagnostics.length, 1);
        assert.deepEqual(position(report.diagnostics[0]), expected);
        const engine = new api.CLIEngine({ binary, useEslintrc: false, baseConfig: { rules: { [rule]: "error" } } });
        assert.deepEqual(position(engine.executeOnText(code, "fixture.js").results[0].messages[0]), expected);
      }
    });
  }
});

test("suppressed diagnostics preserve the same UTF-16 end positions", async (t) => {
  for (const directive of [
    "// utlint-ignore no-debugger: generated breakpoint",
    "// eslint-disable-next-line no-debugger -- generated breakpoint",
  ]) {
    await t.test(directive, async () => {
      const comment = "/* 中文😀 */ ";
      const source = `${directive}\r\n${comment}debugger;`;
      const expected = { line: 2, column: comment.length + 1, endLine: 2, endColumn: comment.length + 10 };
      for (const api of [esm, commonJS]) {
        const report = api.lintText(source, { binary, noConfig: true, rules: ["no-debugger"] });
        assert.deepEqual(report.diagnostics, []);
        assert.equal(report.suppressedDiagnostics.length, 1);
        assert.deepEqual(position(report.suppressedDiagnostics[0]), expected);
        const options = { binary, useEslintrc: false, baseConfig: { rules: { "no-debugger": "error" } } };
        const result = new api.CLIEngine(options).executeOnText(source, "fixture.js").results[0];
        assert.deepEqual(result.messages, []);
        assert.deepEqual(position(result.suppressedMessages[0]), expected);
        const [asyncResult] = await new api.ESLint(options).lintText(source, { filePath: "fixture.js" });
        assert.deepEqual(position(asyncResult.suppressedMessages[0]), expected);
      }
    });
  }
});

test("Linter.verify preserves active and suppressed end positions", (t) => {
  const previousBinary = process.env.UTOO_LINT_BIN;
  process.env.UTOO_LINT_BIN = binary;
  t.after(() => {
    if (previousBinary === undefined) delete process.env.UTOO_LINT_BIN;
    else process.env.UTOO_LINT_BIN = previousBinary;
  });
  for (const api of [esm, commonJS]) {
    const linter = new api.Linter();
    const config = { rules: { "no-debugger": "error" } };
    assert.deepEqual(position(linter.verify("debugger;", config)[0]), { line: 1, column: 1, endLine: 1, endColumn: 10 });
    assert.deepEqual(linter.verify("// eslint-disable-next-line no-debugger\ndebugger;", config), []);
    assert.deepEqual(position(linter.getSuppressedMessages()[0]), { line: 2, column: 1, endLine: 2, endColumn: 10 });
  }
});

test("zero-width parser diagnostics preserve an exclusive EOF position", () => {
  const source = "const value =";
  for (const api of [esm, commonJS]) {
    const result = new api.CLIEngine({ binary, useEslintrc: false, baseConfig: { rules: {} } }).executeOnText(source, "fixture.js").results[0];
    assert.equal(result.messages.length, 1);
    assert.equal(result.messages[0].ruleId, "parse");
    assert.deepEqual(position(result.messages[0]), { line: 1, column: source.length + 1, endLine: 1, endColumn: source.length + 1 });
  }
});

test("I/O errors without source spans do not invent end positions", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "utoo-lint-positions-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const missing = join(directory, "missing.js");
  for (const api of [esm, commonJS]) {
    const result = api.run(["--no-config", "--format=json", missing], { binary });
    assert.equal(result.status, 1);
    const [diagnostic] = JSON.parse(result.stdout).diagnostics;
    assert.equal(diagnostic.ruleId, "io");
    assert.equal(Object.hasOwn(diagnostic, "endLine"), false);
    assert.equal(Object.hasOwn(diagnostic, "endColumn"), false);
    const engine = new api.CLIEngine({ binary, useEslintrc: false, errorOnUnmatchedPattern: false });
    assert.deepEqual(engine.executeOnFiles([missing]).results, []);
  }
});
