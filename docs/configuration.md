# Configuration

`utoo-lint` selects one config from the current working directory or its
ancestors, then applies rule-related CLI overrides.

The canonical config names are:

- `utlint.config.ts`: a typed, executable config loaded by the npm/Node CLI.
- `utlint.config.json`: a static JSON config readable by both the npm CLI and
  the raw native binary.

These are alternative representations of the same active config. They are not
implicitly merged. For the npm/Node entry point, discovery is nearest-first:
all supported names are checked in one directory before the parent directory is
considered. In the same directory, the order is:

1. `utlint.config.ts`
2. `utlint.config.json`
3. `utoo.json` (deprecated)
4. `utoo-lint.json` (deprecated)

This means a nearer `utlint.config.json` wins over a more distant
`utlint.config.ts`. The two legacy JSON names remain temporarily supported for
migration, but new projects should use a canonical name.

Use `--config=path/to/utlint.config.json` to select a config explicitly, or
`--no-config` to ignore local config. Rule-related CLI options such as
`--rules` and individual rule toggles are applied after the selected config.

Project-config `files` and `ignores` patterns are resolved relative to the
selected config file's directory, including when that config is discovered in
an ancestor directory or selected explicitly.

## TypeScript Config

Use `utlint.config.ts` for typed authoring, TypeScript syntax, imports, or
computed configuration:

```ts
import { defineConfig } from "@utoo/lint/config";

export default defineConfig({
  files: ["src/**/*.{js,jsx,ts,tsx}"],
  ignores: ["dist", "node_modules"],
  rules: {
    "no-debugger": "error",
    "no-console": "warn"
  }
});
```

`defineConfig()` accepts config objects and flat config arrays and returns a
flat array. A TypeScript config is trusted executable code: loading it can run
arbitrary code with the permissions of the Node process. Its default export
must be a JSON-serializable config object or flat config array. The loader
transpiles and executes TypeScript syntax; it does not run `tsc` or perform type
checking.

For a flat config array, each entry's `files` and `ignores` select the files to
which that entry applies. Matching entries are combined in array order, so a
later matching rule value overrides an earlier value for the same rule. The npm
CLI, JavaScript API, and fishlint compatibility command apply this rule
resolution separately for each linted file.

The npm wrapper executes the TypeScript file, materializes its result as JSON,
and passes that JSON to the native binary. The raw native binary intentionally
does not execute or discover TypeScript. It searches for `utlint.config.json`
and then the legacy JSON names. Use the npm CLI for `utlint.config.ts`; when
invoking the raw binary directly, use `utlint.config.json`.

The raw binary currently applies only the JSON config's `rules`. Config-driven
`files` and `ignores` filtering, including choosing default lint targets, is an
npm/Node wrapper feature. Pass lint targets explicitly when invoking the raw
binary.

## JSON Config

Use `utlint.config.json` for a static, runtime-independent config:

```json
{
  "$schema": "https://raw.githubusercontent.com/fireairforce/utoo-lint/main/npm/utoo-lint/schema.json",
  "files": ["src/**/*.{js,jsx,ts,tsx}"],
  "ignores": ["dist", "node_modules"],
  "rules": {
    "no-debugger": "error",
    "no-console": "warn"
  }
}
```

ESLint config files are a migration input, not the recommended long-term
configuration format. Generate a native config with:

```bash
npx utoo-lint migrate eslint --from eslint.config.js --output utlint.config.json
```

## Frontend Project Config

For a React or TypeScript frontend project, start by copying the packaged frontend template into the project root:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utlint.config.json
npx utoo-lint src
```

The template includes a `$schema` entry for editor validation and a focused set of browser, import, React, JSX a11y, and TypeScript rules:

```json
{
  "$schema": "https://raw.githubusercontent.com/fireairforce/utoo-lint/main/npm/utoo-lint/schema.json",
  "files": ["src/**/*.{js,jsx,ts,tsx}"],
  "ignores": ["dist", "node_modules"],
  "rules": {
    "no-debugger": "error",
    "no-console": "warn",
    "react/jsx-no-target-blank": "error",
    "jsx-a11y/aria-props": "error",
    "@typescript-eslint/no-unused-vars": "warn"
  }
}
```

`utoo-lint` treats config severities as ESLint-compatible rule toggles. `off`, `0`, and `false` disable a rule. `warn`, `error`, `on`, `1`, `2`, and `true` enable a rule. ESLint-style arrays are accepted; the first item controls severity, and supported option objects are passed to the native rule implementation.

## Rule Names

Use canonical ESLint rule names in `rules`:

```json
{
  "rules": {
    "no-debugger": "error",
    "import/no-duplicates": "error",
    "react/jsx-no-duplicate-props": "error",
    "jsx-a11y/iframe-has-title": "error",
    "@typescript-eslint/no-require-imports": "error"
  }
}
```

Unknown rule names are rejected so typos do not silently pass. See [Rule status](rule-status.md) for the implemented rule list.

## CLI Precedence

Rule-related CLI options are applied after the config file:

```bash
npx utoo-lint --config=utlint.config.json --no-console=off src
```

For one-off focused runs, `--rules` disables every rule first, then enables only the listed rules:

```bash
npx utoo-lint --rules=no-debugger,react/jsx-no-target-blank src
```
