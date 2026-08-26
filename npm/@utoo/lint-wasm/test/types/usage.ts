import {
  createUtooLint,
  lint,
  lintAndFix,
  type LintDiagnostic,
  type LintFixResult,
  type LintOnlyResult,
  type LintResult,
} from "@utoo/lint-wasm";

const linter = await createUtooLint();
const direct: LintResult = linter.lint("debugger;", {
  filePath: "input.js",
  rules: { "no-debugger": "error" },
});
const diagnostic: LintDiagnostic | undefined = direct.diagnostics[0];
void diagnostic?.range;

const lintOnly: LintOnlyResult = await lint("console.log('x');", {
  rules: { "no-console": "warn" },
});
// @ts-expect-error lint-only results deliberately have no output buffer.
void lintOnly.output;

const fixed: LintFixResult = await lintAndFix("const value = 1;;;", {
  rules: { "no-extra-semi": 2 },
});
fixed.output.toUpperCase();

function consume(result: LintResult) {
  if (result.mode === "fix") {
    result.output.toUpperCase();
  } else {
    result.fixed satisfies false;
  }
}
void consume;
