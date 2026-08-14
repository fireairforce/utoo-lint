# utoo-lint

![utoo-lint banner](assets/utoo-lint-banner.png)

`@utoo/lint` is a High performance linter for JavaScript and TypeScript written by Zig.
It uses [`yuku`](https://github.com/yuku-toolchain/yuku) for parsing, AST
traversal, scope tracking, and symbol resolution.

It currently has some performance advantages compared with other lint tools:

![utoo-lint benchmark](assets/utoo-lint-benchmark.png)

## Status

This repo is a working scaffold, not a production linter yet.

- License: [MIT](LICENSE)
- Security: See the [security policy](SECURITY.md) to report vulnerabilities
  privately.

Useful docs:

- [Rule status](docs/rule-status.md) lists implemented rules and their ESLint
  documentation links.
- [Configuration](docs/configuration.md) describes `utlint.config.ts` and
  `utlint.config.json` for frontend projects.
- [Migrating from ESLint](docs/eslint-migration.md) covers the current migration
  path.
- [Contributing](CONTRIBUTING.md) covers local development, rule work,
  packaging, and publishing.

## Install

```bash
pnpm add -D @utoo/lint
```

Run it with:

```bash
pnpm exec utoo-lint src
```

## CLI

```bash
utoo-lint [options] [file-or-directory ...]
```

If no target is provided, the npm CLI uses `files` from the selected config;
when there is no `files` entry, it scans the current directory. It skips `.git`,
`.zig-cache`, `node_modules`, `vendor`, and `zig-out`.

Start a frontend project from the packaged template:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utlint.config.json
pnpm exec utoo-lint src
```

Run only a focused rule set:

```bash
utoo-lint --rules=no-debugger,no-unused-vars,@typescript-eslint/no-unused-vars src
```

Disable a rule from the command line:

```bash
utoo-lint --no-console=off src
```

Use machine-readable output:

```bash
utoo-lint --format=json src
```

The default text output groups diagnostics by file, aligns locations and
severity, and ends with separate error and warning totals. Colors are enabled
for interactive terminals; use `--color` to force them or `--no-color` to
disable them (for example, in snapshot tests). JSON output remains stable for
editor and CI integrations.

### Autofix

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
when a rule or a particular code shape cannot be fixed safely. See
[Rule status](docs/rule-status.md) for per-rule autofix coverage.

## Configuration

The canonical config names are `utlint.config.ts` and `utlint.config.json`.
They are two representations of one active config, not layers that are merged.

| Config | Use it when | Supported entry points |
| --- | --- | --- |
| `utlint.config.ts` | You want typed authoring, imports, or computed values. | npm CLI, JavaScript API, and fishlint compatibility command |
| `utlint.config.json` | You want a static, runtime-independent config. | npm CLI, JavaScript API, fishlint compatibility command, and raw native binary |

For the npm/Node entry point, discovery checks each directory before moving to
its parent, so the nearest config directory wins. Within one directory,
`utlint.config.ts` takes precedence over `utlint.config.json`. The old
`utoo.json` and `utoo-lint.json` names remain temporarily supported after the
canonical names, but are deprecated.

The npm CLI discovers either canonical file automatically. You can also select
one explicitly:

```bash
pnpm exec utoo-lint --config=utlint.config.ts src
pnpm exec utoo-lint --config=utlint.config.json src
```

Use `utlint.config.json` for a static config that both the npm CLI and raw native
binary can read:

```json
{
  "$schema": "https://raw.githubusercontent.com/fireairforce/utoo-lint/main/npm/utoo-lint/schema.json",
  "files": ["src/**/*.{js,jsx,ts,tsx}"],
  "ignores": ["dist", "node_modules"],
  "rules": {
    "no-console": "off",
    "no-debugger": "error",
    "@typescript-eslint/no-unused-vars": ["warn"]
  }
}
```

Use `utlint.config.ts` when the npm/Node CLI should execute a typed config:

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

A TypeScript config is trusted executable code and must export a
JSON-serializable object or flat config array. The npm wrapper executes it,
materializes the result as JSON, and invokes the native binary. The raw binary
does not execute or discover TypeScript; it searches for `utlint.config.json`
and then the legacy JSON names. Invoke the npm CLI for `utlint.config.ts`, or
give the binary `utlint.config.json`. Use `--no-config` to disable config
discovery. Rule-related CLI options such as `--rules` and individual rule
toggles are applied after the selected config.
As in ESLint, a selected config's `rules` map is the complete rule set: rules
that are not configured are disabled. With no selected config, utoo-lint keeps
its built-in default rules.

Project-config `files` and `ignores` patterns are relative to the selected
config file's directory. In a flat config array, those fields determine which
entries match each file; matching entries are combined in order, with later
rule values overriding earlier values. The npm CLI, JavaScript API, and
fishlint compatibility command perform this rule resolution per file.

The raw binary applies only `rules` from JSON config. Config-driven
`files` and `ignores` filtering and default target selection belong to the
npm/Node wrapper; pass lint targets explicitly when invoking the raw binary.

Rule values may be `off`, `warn`, `error`, `0`, `1`, `2`, booleans, or an
ESLint-style array whose first item is the severity and later items are native
rule options. Matching ESLint's CLI behavior, warnings are reported without
making the command fail; errors return exit status 1. The fishlint-compatible
CLI can make warnings fail with `--max-warnings`.

To migrate an existing ESLint config into the native utoo format:

```bash
pnpm exec utoo-lint migrate eslint --from eslint.config.js --output utlint.config.json
```

## JavaScript API

```js
import { lintFiles } from "@utoo/lint";

const report = lintFiles(["src"], {
  config: "utlint.config.json",
  rules: ["no-debugger"]
});
```

Set `fix: true` to compute fixed output without writing files:

```js
const report = lintFiles(["src"], { fix: true });

console.log(report.outputs);
```

## Architecture

- `src/root.zig` owns parsing, rule execution, and public API exports.
- `src/core.zig` owns shared lint types, diagnostics, and common helpers.
- `src/rules/root.zig` registers rules and dispatches AST visitor hooks.
- `src/rules/*.zig` contains one lint rule per file.
- `src/main.zig` owns CLI argument parsing, file discovery, and terminal output.
- `vendor/yuku` is pinned as a git submodule so the parser API is reproducible.

The rule engine deliberately uses Yuku's native flat AST and semantic traverser
instead of converting to ESTree. The native engine has no JavaScript runtime
dependency; the npm configuration layer uses Node only when it loads an
executable project config such as `utlint.config.ts`.
