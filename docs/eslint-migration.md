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

## Add a Config File

Create `utoo.json` in the project root, or copy the packaged frontend template:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utoo.json
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

`utoo-lint` also reads `utoo-lint.json`. Use `--config=path/to/file.json` to select a file explicitly, or `--no-config` to ignore local config.

Rule values support the common ESLint forms:

- `"off"`, `0`, or `false` disable a rule.
- `"warn"`, `"error"`, `1`, `2`, or `true` enable a rule.
- Arrays such as `["error", { ...options }]` use the first item as severity. Rule-specific options are not interpreted yet.

CLI flags are applied after config files, so command-line toggles override config:

```bash
npx utoo-lint --config=utoo.json --no-console=off src
```

## Translate ESLint Rules

Move rules from `eslint.config.js` or `.eslintrc` into `utoo.json` by keeping the same canonical rule names:

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
npx utoo-lint --config=utoo.json src test
```

Once diagnostics match your expectations, replace the ESLint job for that rule set or keep both while expanding rule coverage.

## Replace Fishlint Commands

`@utoo/lint` installs a `fishlint` compatibility command for scripts that already
call the eslint subcommand:

```bash
npx fishlint eslint --disable-setup --config utoo.json --glob src
```

The wrapper invokes `utoo-lint` after translating common fishlint eslint flags.
It forwards `--config`, maps `--glob` values to lint targets, and ignores
fishlint-only setup/debug flags. `--fix` is accepted with a warning because
`utoo-lint` does not apply fixes yet.

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
