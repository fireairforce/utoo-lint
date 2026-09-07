import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { CLIEngine, Linter } from "../index.js";

const require = createRequire(import.meta.url);
const { CLIEngine: CommonJSCLIEngine, Linter: CommonJSLinter } = require("../index.cjs");
const binary = fileURLToPath(new URL(
  `../../../zig-out/bin/utoo-lint${process.platform === "win32" ? ".exe" : ""}`,
  import.meta.url
));
const rule = "@typescript-eslint/no-explicit-any";

test("ESLint APIs expose explicit-any diagnostics, suggestions, and opt-in fixes", () => {
  for (const [Engine, RuleLinter] of [[CLIEngine, Linter], [CommonJSCLIEngine, CommonJSLinter]]) {
    const meta = new RuleLinter().getRules().get(rule).meta;
    assert.equal(meta.fixable, "code");
    assert.equal(meta.hasSuggestions, true);
    const base = { binary, useEslintrc: false };
    const engine = new Engine({ ...base, baseConfig: { rules: { [rule]: "error" } }, fix: true });
    const result = engine.executeOnText("export type Value = any;", "fixture.ts");
    assert.equal(result.errorCount, 1);
    const [message] = result.results[0].messages;
    assert.equal(message.ruleId, rule);
    assert.equal(message.severity, 2);
    assert.equal(message.fix, undefined);
    assert.deepEqual(message.suggestions.map((suggestion) => suggestion.fix.text), ["unknown", "never"]);
    assert.equal(result.results[0].output, undefined);

    const fixing = new Engine({ ...base, baseConfig: { rules: { [rule]: ["error", { fixToUnknown: true }] } }, fix: true });
    assert.equal(fixing.executeOnText("export type Value = any;", "fixture.ts").results[0].output, "export type Value = unknown;");
    const rest = new Engine({ ...base, baseConfig: { rules: { [rule]: ["error", { ignoreRestArgs: true }] } } });
    assert.equal(rest.executeOnText("declare function call(...args: any[]): void;", "fixture.ts").errorCount, 0);
  }
});
