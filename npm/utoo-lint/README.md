# @utoo/lint

![utoo-lint logo](assets/utoo-lint-logo.svg)

High performance linter for JavaScript and TypeScript written by Zig.

## Install

```bash
pnpm add -D @utoo/lint
```

## CLI

Run the linter with:

```bash
pnpm exec utoo-lint src
```

If no target is provided, `utoo-lint` uses `files` from the selected
`utlint.config.ts` or `utlint.config.json`. When no config file or `files` entry
exists, it scans the current directory. It skips `.git`, `.zig-cache`,
`node_modules`, `vendor`, and `zig-out`.

Use a config file:

```bash
pnpm exec utoo-lint --config=utlint.config.json src
```

Run a focused rule set:

```bash
pnpm exec utoo-lint --rules=no-debugger,no-console src
```

Use machine-readable output:

```bash
pnpm exec utoo-lint --format=json src
```

The default terminal output groups diagnostics by file, aligns their location
and severity, and summarizes errors and warnings separately. Color is detected
automatically; pass `--color` to force it or `--no-color` to disable it. JSON
output remains stable for editor and CI integrations.

## Autofix

Apply safe fixes from all enabled rules that support autofix:

```bash
pnpm exec utoo-lint --fix src
```

Preview the result without changing files:

```bash
pnpm exec utoo-lint --fix-dry-run --format=json src
```

`--fix` writes fixed source back to disk. `--fix-dry-run` never writes files;
with JSON output, changed sources are returned in the `outputs` array. Fixes run
until the source is stable, subject to a safety pass limit. Diagnostics remain
when a rule or a particular code shape cannot be fixed safely. The current
[rule status](https://github.com/fireairforce/utoo-lint/blob/main/docs/rule-status.md)
lists autofix coverage by rule.

## Configuration

`utoo-lint` supports two canonical project config formats:

| Config | Use it when | Raw native binary |
| --- | --- | --- |
| `utlint.config.ts` | You want typed authoring, imports, or computed values. | No |
| `utlint.config.json` | You want a static, runtime-independent config. | Yes |

The npm CLI discovers either format automatically. It can also select one
explicitly:

```bash
pnpm exec utoo-lint --config=utlint.config.ts src
pnpm exec utoo-lint --config=utlint.config.json src
```

For a static config readable by both the npm CLI and raw native binary, create
`utlint.config.json`:

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

For a typed config executed by the npm/Node CLI, create `utlint.config.ts`:

```ts
import { defineConfig } from "@utoo/lint/config";

export default defineConfig({
  files: ["src/**/*.{js,jsx,ts,tsx}"],
  ignores: ["dist", "node_modules"],
  rules: {
    "no-console": "off",
    "no-debugger": "error"
  }
});
```

Use `globalIgnores()` as a separate config entry when files or directories
must be excluded from every entry:

```ts
import { defineConfig, globalIgnores } from "@utoo/lint/config";

export default defineConfig(
  globalIgnores(["dist/", ".next/", "**/generated/"]),
  {
    files: ["**/*.{js,jsx,ts,tsx}"],
    rules: {
      "no-debugger": "error"
    }
  }
);
```

`globalIgnores()` returns an ignore-only object containing `ignores` and a
generated `name`. Only such global entries prune directories during target
discovery. By contrast, `ignores` beside `files`, `rules`, or another config
key is entry-scoped: it prevents that entry from applying to matching files,
but does not exclude them from other entries. With no CLI targets, global
ignores filter the config's `files` patterns, or the current-directory scan
when no `files` are configured. Directory patterns such as `dist/` and
`.next/` are relative to the config; use `**/generated/` to match at any depth.
This intentionally follows [ESLint flat config ignore semantics](https://eslint.org/docs/latest/use/configure/ignore).

The two canonical names represent one active config and are not implicitly
merged. For the npm/Node entry point, discovery is nearest-directory-first.
Within the same directory, `utlint.config.ts` takes precedence over
`utlint.config.json`; deprecated `utoo.json` and `utoo-lint.json` files are
checked afterward for temporary backward compatibility. Rule-related CLI
options such as `--rules`, individual rule toggles, and fishlint's `--rule` are
applied after the selected config.

Project-config `files` and `ignores` patterns are relative to the selected
config file's directory. In a flat config array, they select the entries that
apply to each file; matching entries are combined in order and later rule
values override earlier values. The npm CLI, JavaScript API, and fishlint
compatibility command perform this rule resolution per file.

TypeScript config is trusted executable code. Its default export must be a
JSON-serializable object or flat config array. The npm wrapper executes it and
materializes the result as JSON before invoking the native binary. The raw
binary does not execute or discover TypeScript; it searches for
`utlint.config.json` and then the legacy JSON names. Direct native use therefore
requires a JSON config. The raw binary applies only its `rules`;
config-driven `files` and `ignores` filtering and default target selection are
npm/Node wrapper features. Pass lint targets explicitly when invoking the raw
binary. As in ESLint, selecting a config disables rules not present in its
resolved `rules` map. When no config is selected, utoo-lint uses its built-in
default rules.

Rule severities use ESLint's exit behavior: warnings are reported with exit
status 0, while errors return exit status 1. Use fishlint's `--max-warnings`
option when warnings should fail CI.

Start from the packaged frontend template:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utlint.config.json
```

## ESLint Migration

Convert an existing ESLint config into the native utoo format:

```bash
pnpm exec utoo-lint migrate eslint --from eslint.config.js --output utlint.config.json
```

The package also provides compatibility bins for common replacement flows:

```bash
pnpm exec eslint --config utlint.config.json src
pnpm exec fishlint eslint --disable-setup --config utlint.config.json --glob src
```

## JavaScript API

```js
import { lintFiles } from "@utoo/lint";

const report = lintFiles(["src"], {
  config: "utlint.config.json",
  rules: ["no-debugger"]
});

console.log(report.diagnostics);
```

Calling `lintFiles()` without patterns follows the same default target behavior
as the CLI, so migration scripts usually do not need to expand config `files`
manually.

CommonJS is supported through `require("@utoo/lint")`.

Set `fix: true` to compute fixed output through the JavaScript API. Raw
`lintFiles()` and `lintText()` reports expose changed sources in `outputs`
without writing them. The ESLint-compatible API follows the usual two-step
flow:

```js
import { ESLint } from "@utoo/lint";

const eslint = new ESLint({ fix: true });
const results = await eslint.lintFiles(["src"]);
await ESLint.outputFixes(results);
```

## Binary Resolution

`@utoo/lint` installs a platform-specific optional dependency containing the
native `utoo-lint` binary. Set `UTOO_LINT_BIN=/path/to/utoo-lint` to force a
specific binary during local development.
