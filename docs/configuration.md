# Configuration

`utoo-lint` reads a config file from the current working directory or its ancestors before applying CLI flags.

Supported config file names:

- `utoo.json`
- `utoo-lint.json`

Use `--config=path/to/utoo.json` to select a config explicitly, or `--no-config` to ignore local config.
JavaScript flat config files are supported by the JavaScript API for JSON-serializable `rules`, `files`, and `ignores` entries.

ESLint config files are a migration input, not the recommended long-term
configuration format. Generate a native config with:

```bash
npx utoo-lint migrate eslint --from eslint.config.js --output utoo.json
```

## Frontend Project Config

For a React or TypeScript frontend project, start by copying the packaged frontend template into the project root:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utoo.json
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

`utoo-lint` currently treats config severities as ESLint-compatible rule toggles. `off`, `0`, and `false` disable a rule. `warn`, `error`, `on`, `1`, `2`, and `true` enable a rule. ESLint-style arrays are accepted, but only the first item is interpreted today; rule-specific options are reserved for future support.

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

CLI flags are applied after the config file:

```bash
npx utoo-lint --config=utoo.json --no-console=off src
```

For one-off focused runs, `--rules` disables every rule first, then enables only the listed rules:

```bash
npx utoo-lint --rules=no-debugger,react/jsx-no-target-blank src
```
