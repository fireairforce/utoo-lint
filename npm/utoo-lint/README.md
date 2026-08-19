# @utoo/lint

![utoo-lint logo](assets/utoo-lint-logo.svg)

[![npm version](https://img.shields.io/npm/v/%40utoo%2Flint?logo=npm)](https://www.npmjs.com/package/@utoo/lint)
[![Node.js 20+](https://img.shields.io/badge/Node.js-%3E%3D20-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![CI](https://github.com/fireairforce/utoo-lint/actions/workflows/ci.yml/badge.svg)](https://github.com/fireairforce/utoo-lint/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/fireairforce/utoo-lint)](https://github.com/fireairforce/utoo-lint/blob/main/LICENSE)

A high-performance linter for JavaScript and TypeScript, written in Zig and
powered by [Yuku](https://github.com/yuku-toolchain/yuku).

`@utoo/lint` combines a native lint engine with familiar configuration, CLI,
and JavaScript APIs.

[Installation](#installation) · [Quick start](#quick-start) ·
[Rules](https://github.com/fireairforce/utoo-lint/blob/main/docs/rule-status.md) ·
[Configuration](https://github.com/fireairforce/utoo-lint/blob/main/docs/configuration.md) ·
[GitHub](https://github.com/fireairforce/utoo-lint)

## Why utoo-lint?

- **Native performance** — Zig and Yuku power parsing, semantic analysis, and
  parallel file linting.
- **Broad rule coverage** — More than 300 rules cover JavaScript, TypeScript,
  React, JSX accessibility, and imports.
- **Familiar configuration** — Use typed `utlint.config.ts` or static
  `utlint.config.json`, with ESLint-style rule names and severities.
- **Practical workflows** — Safe autofix, suppression comments, JSON output,
  and ESM/CommonJS APIs are included.
- **Portable installation** — Prebuilt binaries are available for macOS,
  Linux, and Windows on supported architectures.

## Installation

`@utoo/lint` requires Node.js 20 or later.

### utoo

[utoo](https://utoo.land/en/docs/utoo) is a fast, npm-compatible package
manager written in Rust. Install it once if it is not already available:

```bash
npm install -g utoo
```

Add `@utoo/lint` as a development dependency:

```bash
ut install @utoo/lint -D
```

In an existing project, run `ut install` without a package name to install all
dependencies declared in `package.json`.

### Other package managers

```bash
pnpm add -D @utoo/lint
npm install --save-dev @utoo/lint
```

The package selects the native binary for the current platform. No Zig
toolchain is required.

## Quick start

### Run with the default rules

```bash
utx @utoo/lint src
```

Without a config file, `utoo-lint` uses its built-in default rules. It supports
`.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs`, `.mts`, and `.cts` files.

### Add a typed config

Create `utlint.config.ts`:

```ts
import { defineConfig, globalIgnores } from "@utoo/lint/config";
import frontend from "@utoo/lint/configs/frontend";

export default defineConfig(
  globalIgnores(["dist/", "coverage/"]),
  {
    ...frontend,
    files: ["src/**/*.{js,jsx,ts,tsx}"],
    rules: {
      ...frontend.rules,
      "no-console": "warn"
    }
  }
);
```

The CLI discovers the config and uses its `files` patterns:

```bash
utx @utoo/lint
```

See the
[configuration guide](https://github.com/fireairforce/utoo-lint/blob/main/docs/configuration.md)
for flat config arrays, global ignores, rule options, and config precedence.

### Add package scripts

```json
{
  "scripts": {
    "lint": "utoo-lint src",
    "lint:fix": "utoo-lint --fix src"
  }
}
```

With utoo, run these scripts as `ut lint` and `ut lint:fix`.

## Common commands

| Task | Command |
| --- | --- |
| Lint files | `utx @utoo/lint src` |
| Apply safe fixes | `utx @utoo/lint --fix src` |
| Preview fixes as JSON | `utx @utoo/lint --fix-dry-run --format=json src` |
| Select rules for one run | `utx @utoo/lint --rules=no-debugger,no-unused-vars src` |
| Use an explicit config | `utx @utoo/lint --config=utlint.config.json src` |

Run `utx @utoo/lint --help` for all CLI options.

## Configuration

`utoo-lint` supports two canonical config formats. They are alternative
representations of one active config and are not merged together.

| Config | Best for | Raw native binary |
| --- | --- | --- |
| `utlint.config.ts` | Typed authoring, imports, presets, and computed values | No |
| `utlint.config.json` | Static configuration and JSON Schema validation | Yes |

Rule severities follow ESLint conventions: `off`, `warn`, `error`, `0`, `1`,
and `2`. A selected config enables only the rules present in its resolved
`rules` map.

The npm CLI and JavaScript API load both formats. The raw native binary loads
JSON only. See the
[configuration guide](https://github.com/fireairforce/utoo-lint/blob/main/docs/configuration.md)
for the complete behavior.

## Autofix

Apply safe fixes in place:

```bash
utx @utoo/lint --fix src
```

Preview fixes without writing files:

```bash
utx @utoo/lint --fix-dry-run --format=json src
```

Fixes run until the source is stable, subject to a safety pass limit. The
[rule status](https://github.com/fireairforce/utoo-lint/blob/main/docs/rule-status.md)
documents autofix support for each rule.

## Suppression comments

Use suppression comments for intentional exceptions without disabling a rule
in project configuration:

```js
// utlint-ignore no-debugger: generated breakpoint
debugger;
```

| Directive | Scope |
| --- | --- |
| `utlint-ignore [rule]` | The next line of code |
| `utlint-ignore-all [rule]` | The entire file when placed before any code |
| `utlint-ignore-start [rule]` | The start of a suppressed range |
| `utlint-ignore-end [rule]` | The end of a suppressed range |

A directive may target one rule ID. Omitting it creates or closes an all-rules
suppression. Parse errors are never suppressed, and suppressed fixes are not
applied.

See the
[suppression comments guide](https://github.com/fireairforce/utoo-lint/blob/main/docs/suppressions.md)
for range examples and API behavior.

## Migrating from ESLint

Convert an existing ESLint config into a native utoo-lint config:

```bash
utx @utoo/lint migrate eslint \
  --from eslint.config.js \
  --output utlint.config.json
```

The package also exposes `eslint` and `fishlint` compatibility commands for
incremental replacement workflows. See the
[migration guide](https://github.com/fireairforce/utoo-lint/blob/main/docs/eslint-migration.md)
for supported mappings and known differences.

## JavaScript API

The package provides ESM and CommonJS entry points:

```js
import { lintFiles } from "@utoo/lint";

const report = lintFiles(["src"], {
  config: "utlint.config.ts"
});

console.log(report.diagnostics);
```

An ESLint-style API is also available:

```js
import { ESLint } from "@utoo/lint";

const eslint = new ESLint({ fix: true });
const results = await eslint.lintFiles(["src"]);
await ESLint.outputFixes(results);
```

Raw reports include active diagnostics, suppressed diagnostics, fixed outputs,
and an exit code. The compatibility layer also exports `Linter`, `CLIEngine`,
`RuleTester`, and `SourceCode` APIs.

## Supported platforms

The package installs a platform-specific optional dependency containing the
native binary.

| Operating system | Architectures |
| --- | --- |
| macOS | arm64, x64 |
| Linux | arm64, x64 |
| Windows | x64 |

Set `UTOO_LINT_BIN=/path/to/utoo-lint` to use a custom binary during local
development.

## Documentation

- [Rule status](https://github.com/fireairforce/utoo-lint/blob/main/docs/rule-status.md)
- [Configuration](https://github.com/fireairforce/utoo-lint/blob/main/docs/configuration.md)
- [Suppression comments](https://github.com/fireairforce/utoo-lint/blob/main/docs/suppressions.md)
- [Migrating from ESLint](https://github.com/fireairforce/utoo-lint/blob/main/docs/eslint-migration.md)
- [Benchmarks](https://github.com/fireairforce/utoo-lint/tree/main/benchmarks)
- [Security policy](https://github.com/fireairforce/utoo-lint/blob/main/SECURITY.md)

## License

[MIT](https://github.com/fireairforce/utoo-lint/blob/main/LICENSE)
