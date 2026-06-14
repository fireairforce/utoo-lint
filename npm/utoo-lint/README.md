# @utoo/lint

![utoo-lint logo](assets/utoo-lint-logo.svg)

High performance linter for JavaScript and TypeScript written by Zig.

## Install

```bash
npm install -D @utoo/lint
```

## CLI

Run the linter with:

```bash
npx utoo-lint src
```

If no target is provided, `utoo-lint` scans the current directory. It skips
`.git`, `.zig-cache`, `node_modules`, `vendor`, and `zig-out`.

Use a config file:

```bash
npx utoo-lint --config=utoo.json src
```

Run a focused rule set:

```bash
npx utoo-lint --rules=no-debugger,no-console src
```

Use machine-readable output:

```bash
npx utoo-lint --format=json src
```

## Configuration

Create a `utoo.json` file:

```json
{
  "$schema": "https://raw.githubusercontent.com/fireairforce/utoo-lint/main/npm/utoo-lint/schema.json",
  "files": ["src/**/*.{js,jsx,ts,tsx}"],
  "ignores": ["dist", "node_modules"],
  "rules": {
    "no-console": "off",
    "no-debugger": "error"
  }
}
```

Start from the packaged frontend template:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utoo.json
```

## ESLint Migration

Convert an existing ESLint config into the native utoo format:

```bash
npx utoo-lint migrate eslint --from eslint.config.js --output utoo.json
```

The package also provides compatibility bins for common replacement flows:

```bash
npx eslint --config utoo.json src
npx fishlint eslint --disable-setup --config utoo.json --glob src
```

## JavaScript API

```js
import { lintFiles } from "@utoo/lint";

const report = lintFiles(["src"], {
  config: "utoo.json",
  rules: ["no-debugger"]
});

console.log(report.diagnostics);
```

CommonJS is supported through `require("@utoo/lint")`.

## Binary Resolution

`@utoo/lint` installs a platform-specific optional dependency containing the
native `utoo-lint` binary. Set `UTOO_LINT_BIN=/path/to/utoo-lint` to force a
specific binary during local development.
