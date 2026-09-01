import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  UtooLintWasmError,
  createUtooLint,
} from "../npm/@utoo/lint-wasm/index.js";

const wasmPath = process.argv[2];
if (!wasmPath) throw new Error("usage: node tests/wasm.mjs <utoo-lint.wasm>");

const wasmBytes = await readFile(wasmPath);
const wasmModule = await WebAssembly.compile(wasmBytes);
const linter = await createUtooLint({ wasm: wasmModule });
const rawInstance = await WebAssembly.instantiate(wasmModule, {});
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

function callRaw(source, optionsJson) {
  const { alloc, free, lint: rawLint, memory } = rawInstance.exports;
  const sourceBytes = typeof source === "string" ? textEncoder.encode(source) : source;
  const optionsBytes = textEncoder.encode(optionsJson);
  const sourceLength = sourceBytes.length || 1;
  const optionsLength = optionsBytes.length || 1;
  const sourcePtr = alloc(sourceBytes.length);
  let optionsPtr = 0;
  let resultPtr = 0;
  let resultLength = 0;

  try {
    new Uint8Array(memory.buffer, sourcePtr, sourceBytes.length).set(sourceBytes);
    optionsPtr = alloc(optionsBytes.length);
    new Uint8Array(memory.buffer, optionsPtr, optionsBytes.length).set(optionsBytes);
    resultPtr = rawLint(sourcePtr, sourceBytes.length, optionsPtr, optionsBytes.length);
    assert.notEqual(resultPtr, 0);
    const payloadLength = new DataView(memory.buffer).getUint32(resultPtr, true);
    resultLength = payloadLength + 4;
    const payload = new Uint8Array(memory.buffer, resultPtr + 4, payloadLength).slice();
    return JSON.parse(textDecoder.decode(payload));
  } finally {
    if (resultPtr !== 0) free(resultPtr, resultLength);
    if (optionsPtr !== 0) free(optionsPtr, optionsLength);
    free(sourcePtr, sourceLength);
  }
}

test("exports a standalone ABI v1 module", () => {
  assert.deepEqual(WebAssembly.Module.imports(wasmModule), []);
  const exports = new Set(WebAssembly.Module.exports(wasmModule).map((item) => item.name));
  for (const name of ["memory", "abi_version", "alloc", "free", "lint"]) {
    assert.ok(exports.has(name), `missing WebAssembly export ${name}`);
  }
  assert.equal(linter.abiVersion, 1);
});

test("uses defaults only when rules is absent", () => {
  const defaults = linter.lint("debugger;", { filePath: "input.js" });
  assert.ok(defaults.diagnostics.some((item) => item.ruleId === "no-debugger"));

  const empty = linter.lint("debugger;", { filePath: "input.js", rules: {} });
  assert.ok(!empty.diagnostics.some((item) => item.ruleId === "no-debugger"));
});

test("parses JS, TS, JSX, and TSX by file name", () => {
  const fixtures = [
    ["input.js", "export const value = 1;"],
    ["input.ts", "export const value: number = 1;"],
    ["input.jsx", "export const value = <div />;"],
    ["input.tsx", "export const value: JSX.Element = <div />;"],
  ];

  for (const [filePath, source] of fixtures) {
    const result = linter.lint(source, { filePath, rules: {} });
    assert.deepEqual(
      result.diagnostics.filter((item) => item.ruleId === "parse"),
      [],
      filePath,
    );
  }
});

test("returns parser failures as diagnostics", () => {
  const result = linter.lint("const = ;", { filePath: "input.js", rules: {} });
  assert.ok(result.diagnostics.some((item) => item.ruleId === "parse"));
});

test("applies configured severity and UTF-16 ranges", () => {
  const source = `const emoji = "😀中";\nconsole.log(emoji);`;
  const result = linter.lint(source, {
    filePath: "unicode.js",
    rules: { "no-console": "warn" },
  });
  const diagnostic = result.diagnostics.find((item) => item.ruleId === "no-console");
  assert.ok(diagnostic);
  assert.equal(diagnostic.severity, "warning");
  assert.match(source.slice(...diagnostic.range), /console/);
  assert.equal(result.offsetEncoding, "utf-16");
  assert.equal(result.diagnosticsSource, "input");
});

test("applies no-magic-numbers Number and BigInt ignore values", () => {
  const result = linter.lint("call(7, 8n, 9);", {
    filePath: "numbers.js",
    rules: { "no-magic-numbers": ["error", { ignore: [7, "8n"] }] },
  });
  const diagnostics = result.diagnostics.filter(
    (item) => item.ruleId === "no-magic-numbers",
  );
  assert.equal(diagnostics.length, 1);
  assert.equal(diagnostics[0].message, "No magic number: 9.");
});

test("applies configured Jest versions to version-aware rules", () => {
  const source = "jest.runTimersToTime(1000);";
  const oldJest = linter.lint(source, {
    filePath: "input.js",
    settings: { jest: { version: "21.4.0" } },
    rules: { "jest/no-deprecated-functions": "error" },
  });
  assert.equal(oldJest.diagnostics.length, 0);

  const newJest = linter.lint(source, {
    filePath: "input.js",
    settings: { jest: { version: 22 } },
    rules: { "jest/no-deprecated-functions": "error" },
  });
  assert.equal(newJest.diagnostics.length, 1);
  assert.equal(newJest.diagnostics[0].ruleId, "jest/no-deprecated-functions");
  assert.equal(newJest.diagnostics[0].fixes.length, 2);
});

test("reports exports from files containing Jest tests", () => {
  const result = linter.lint(
    "export const helper = 1; test('export', () => expect(helper).toBe(1));",
    {
      filePath: "input.js",
      rules: { "jest/no-export": "error" },
    },
  );
  assert.equal(result.diagnostics.length, 1);
  assert.equal(result.diagnostics[0].ruleId, "jest/no-export");
  assert.equal(result.diagnostics[0].message, "Do not export from a test file");
});

test("reports focused Jest tests with non-automatic suggestions", () => {
  const source = "context.only('suite', () => {});";
  const result = linter.lint(source, {
    filePath: "input.js",
    settings: { jest: { globalAliases: { describe: ["context"] } } },
    rules: { "jest/no-focused-tests": "error" },
  });
  assert.equal(result.diagnostics.length, 1);
  assert.equal(result.diagnostics[0].ruleId, "jest/no-focused-tests");
  assert.equal(result.diagnostics[0].fixes.length, 0);
  assert.deepEqual(result.diagnostics[0].suggestions, [
    { desc: "Remove focus from test", fix: [{ range: [7, 12], text: "" }] },
  ]);

  const fixed = linter.lintAndFix(source, {
    filePath: "input.js",
    settings: { jest: { globalAliases: { describe: ["context"] } } },
    rules: { "jest/no-focused-tests": "error" },
  });
  assert.equal(fixed.fixed, false);
  assert.equal(fixed.output, source);
});

test("reports identical Jest titles at the same suite level", () => {
  const result = linter.lint(
    "describe('group', () => { it('same', () => {}); test('same', () => {}); });",
    {
      filePath: "input.js",
      rules: { "jest/no-identical-title": "error" },
    },
  );
  assert.equal(result.diagnostics.length, 1);
  assert.equal(result.diagnostics[0].ruleId, "jest/no-identical-title");
  assert.equal(
    result.diagnostics[0].message,
    "Test title is used multiple times in the same describe block",
  );
});

test("reports interpolation in inline Jest snapshots", () => {
  const result = linter.lint(
    "expect(value).toMatchInlineSnapshot({}, `${value}`);",
    {
      filePath: "input.js",
      rules: { "jest/no-interpolation-in-snapshots": "error" },
    },
  );
  assert.equal(result.diagnostics.length, 1);
  assert.equal(result.diagnostics[0].ruleId, "jest/no-interpolation-in-snapshots");
  assert.equal(
    result.diagnostics[0].message,
    "Do not use string interpolation inside of snapshots",
  );
});

test("applies control-flow-aware no-useless-assignment analysis", () => {
  const result = linter.lint(
    "let value = 1; console.log(value); value = 2;",
    {
      filePath: "assignment.js",
      rules: { "no-useless-assignment": "error" },
    },
  );
  const diagnostics = result.diagnostics.filter(
    (item) => item.ruleId === "no-useless-assignment",
  );
  assert.equal(diagnostics.length, 1);
  assert.equal(
    diagnostics[0].message,
    "This assigned value is not used in subsequent statements.",
  );
});

test("applies autofixes and reports diagnostics against output", () => {
  const result = linter.lintAndFix("const value = 1;;;", {
    filePath: "fix.js",
    rules: { "no-extra-semi": "error" },
  });
  assert.equal(result.mode, "fix");
  assert.equal(result.diagnosticsSource, "output");
  assert.equal(result.fixed, true);
  assert.equal(result.output, "const value = 1;");
  assert.equal(result.passes, 1);
  assert.ok(result.appliedDiagnostics > 0);
  assert.ok(!result.diagnostics.some((item) => item.ruleId === "no-extra-semi"));
});

test("preserves suppression metadata", () => {
  const source = "// utlint-ignore no-debugger: generated breakpoint\ndebugger;";
  const result = linter.lint(source, {
    filePath: "suppressed.js",
    rules: { "no-debugger": "error" },
  });
  assert.equal(result.diagnostics.length, 0);
  assert.equal(result.suppressedDiagnostics.length, 1);
  assert.equal(result.suppressedDiagnostics[0].ruleId, "no-debugger");
  assert.equal(result.suppressedDiagnostics[0].suppression?.justification, "generated breakpoint");
});

test("reports filesystem-backed rules as skipped", () => {
  const result = linter.lint('import value from "./missing.js";', {
    filePath: "input.js",
    rules: { "import/no-unresolved": "error" },
  });
  assert.deepEqual(result.skippedRules, ["import/no-unresolved"]);
});

test("returns structured configuration errors", () => {
  assert.throws(
    () => linter.lint("value;", { rules: { "not-a-rule": "error" } }),
    (error) => {
      assert.ok(error instanceof UtooLintWasmError);
      assert.equal(error.code, "UNKNOWN_RULE");
      assert.equal(error.ruleId, "not-a-rule");
      return true;
    },
  );
});

test("returns structured raw ABI request errors", () => {
  assert.equal(callRaw("value;", "{").error.code, "INVALID_OPTIONS_JSON");
  assert.equal(
    callRaw("value;", JSON.stringify({ version: 2 })).error.code,
    "UNSUPPORTED_VERSION",
  );
  assert.equal(
    callRaw(new Uint8Array([0xff]), JSON.stringify({ version: 1 })).error.code,
    "INVALID_UTF8",
  );
});

test("supports empty and repeated calls across memory growth", () => {
  for (let index = 0; index < 25; index += 1) {
    const source = index === 24 ? `const text = "${"x".repeat(200_000)}";` : "";
    const result = linter.lint(source, { filePath: "input.js", rules: {} });
    assert.equal(result.ok, true);
  }
});
