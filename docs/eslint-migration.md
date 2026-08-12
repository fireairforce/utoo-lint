# Migrating from ESLint

This guide covers the current migration path from ESLint to `utoo-lint`.

`utoo-lint` is still experimental. Migrate incrementally: start with a small shared rule set, compare diagnostics in CI, then expand coverage as matching rules land.

## Install and Run

```bash
npm install --save-dev @utoo/lint
npx utoo-lint src test
```

For a focused first pass, run only rules that already exist in both projects:

```bash
npx utoo-lint --rules=no-debugger,no-unused-vars,@typescript-eslint/no-unused-vars src
```

## Generate a utoo Config

Use the migration command to turn an existing ESLint config into the canonical
static config, `utlint.config.json`:

```bash
npx utoo-lint migrate eslint --from eslint.config.js --output utlint.config.json
```

The generated config is a native `utoo-lint` config, not an ESLint config
executed through a compatibility layer. The current migrator flattens ESLint
flat-config entries into one JSON object: it unions `files` and `ignores`, and
later entries win when the same supported rule appears more than once. Review
the result manually when entries give one rule different per-file values. It
also skips formatter-only rules such as `prettier/prettier` and reports
unsupported rules that still need a native utoo rule or a deliberate
replacement.

For a preview without writing a file:

```bash
npx utoo-lint migrate eslint --print --report=json
```

The selected value for each rule is preserved, including arrays such as
`["error", { ...options }]`. Native utoo rules consume the options they support;
unsupported rules are reported instead of being copied.

## Add a Config File

Create `utlint.config.json` in the project root, or copy the packaged frontend
template:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utlint.config.json
```

Minimal config:

```json
{
  "$schema": "https://raw.githubusercontent.com/fireairforce/utoo-lint/main/npm/utoo-lint/schema.json",
  "rules": {
    "no-debugger": "error",
    "no-console": "off",
    "no-unused-vars": "warn",
    "@typescript-eslint/no-unused-vars": ["warn"],
    "react/jsx-no-target-blank": "error",
    "jsx-a11y/aria-props": "error"
  }
}
```

The canonical names are `utlint.config.ts` and `utlint.config.json`. They are
two representations of one active config and are not implicitly merged.
For the npm/Node entry point, discovery checks the nearest directory first;
within the same directory, `utlint.config.ts` wins over
`utlint.config.json`. The old `utoo.json` and `utoo-lint.json` names remain
temporarily supported after the canonical names, but are deprecated. Use
`--config=path/to/utlint.config.json` to select a file explicitly, or
`--no-config` to ignore local config.

Project-config `files` and `ignores` patterns are relative to the selected
config file's directory. For flat config arrays, entries are matched per file
and combined in array order; later matching rule values override earlier ones.
The npm CLI, JavaScript API, and fishlint compatibility command use this
per-file rule resolution.

The npm/Node CLI can also execute a trusted typed config. Its default export
must be a JSON-serializable object or flat config array:

```ts
// utlint.config.ts
import { defineConfig } from "@utoo/lint/config";

export default defineConfig({
  files: ["src/**/*.{js,jsx,ts,tsx}"],
  rules: {
    "no-debugger": "error",
    "@typescript-eslint/no-unused-vars": "warn"
  }
});
```

Loading `utlint.config.ts` executes project code. The npm wrapper materializes
the exported value as JSON for the native binary; the raw binary itself does
not execute or discover TypeScript. It searches for `utlint.config.json` and
then the legacy JSON names, so use JSON when invoking it directly. The raw
binary currently applies only `rules` from that JSON; config-driven `files` and
`ignores` filtering and default target selection are npm/Node wrapper features.
Pass lint targets explicitly when invoking the raw binary.

Rule values support the common ESLint forms:

- `"off"`, `0`, or `false` disable a rule.
- `"warn"`, `"error"`, `1`, `2`, or `true` enable a rule.
- Arrays such as `["error", { ...options }]` use the first item as severity and pass supported options to the native rule implementation.

Rule-related CLI options are applied after the config, so command-line rule
toggles override configured rule values:

```bash
npx utoo-lint --config=utlint.config.json --no-console=off src
```

## Translate ESLint Rules Manually

Move rules from `eslint.config.js` or `.eslintrc` into
`utlint.config.json` by keeping the same canonical rule names:

```js
// eslint.config.js
export default [
  {
    rules: {
      "no-debugger": "error",
      "@typescript-eslint/no-unused-vars": ["warn"],
      "react/jsx-no-target-blank": "error"
    }
  }
];
```

```json
{
  "rules": {
    "no-debugger": "error",
    "@typescript-eslint/no-unused-vars": ["warn"],
    "react/jsx-no-target-blank": "error"
  }
}
```

Use [Rule status](rule-status.md) to confirm which ESLint, TypeScript ESLint, React, import, and JSX a11y rules are currently implemented.

## Compare in CI

Run ESLint and `utoo-lint` side by side until the selected rule set is stable:

```bash
npx eslint src test
npx utoo-lint --config=utlint.config.json src test
```

Once diagnostics match your expectations, replace the ESLint job for that rule set or keep both while expanding rule coverage.

## Replace Fishlint Commands

`@utoo/lint` installs a `fishlint` compatibility command for scripts that already
call the eslint subcommand:

```bash
npx fishlint eslint --disable-setup --config utlint.config.json --ext .js,.ts --glob src
```

The wrapper invokes `utoo-lint` after translating common fishlint eslint flags.
It forwards `--config`, maps `--glob` values to lint targets, accepts `--ext`
for compatibility, and ignores fishlint-only setup/debug flags. `--fix` applies
fixes from supported native rules, while `--fix-dry-run` computes fixed output
without writing files. It discovers `utlint.config.ts`, `utlint.config.json`,
the deprecated `utoo.json`/`utoo-lint.json` names, and ESLint migration inputs
such as `eslint.config.js`/`eslint.config.mjs`/`eslint.config.cjs`. Executable
configs are loaded and materialized as temporary JSON before invoking the
native binary.

Fishlint presets often include `prettier/prettier`. `utoo-lint` accepts that rule
in config files for compatibility and ignores it because formatting remains
outside the native linter.

## Replace ESLint API Calls

For scripts that already use ESLint's Node API, import `ESLint` from `@utoo/lint`
and keep the high-level call shape:

```js
import { ESLint } from "@utoo/lint";

const eslint = new ESLint({
  useEslintrc: false,
  overrideConfig: {
    rules: {
      "no-debugger": "warn",
      "no-console": "warn"
    }
  }
});

const results = await eslint.lintFiles(["src"]);
const formatter = await eslint.loadFormatter("stylish");
console.log(formatter.format(results));
```

`ESLint#lintText()` is also supported. It writes the text to a temporary file and
maps diagnostics back to the provided `filePath`, which is useful for editor,
pre-commit, and codemod integrations:

```js
const [result] = await eslint.lintText("debugger;\n", {
  filePath: "inline.js"
});
```

Older integrations that still use ESLint's legacy `CLIEngine` can import a
small synchronous facade:

```js
import { CLIEngine } from "@utoo/lint";

const cli = new CLIEngine({
  useEslintrc: false,
  baseConfig: {
    rules: {
      "no-debugger": "error"
    }
  }
});

const report = cli.executeOnFiles(["src"]);
console.log(cli.getFormatter("stylish")(report.results));
```
