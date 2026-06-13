# utoo-lint

![utoo-lint logo](assets/utoo-lint-logo.svg)

`@utoo/lint` is an experimental JavaScript and TypeScript linter written in Zig.
It uses [`yuku`](https://github.com/yuku-toolchain/yuku) (GitHub: https://github.com/yuku-toolchain/yuku) for parsing, AST traversal, scope tracking, and symbol resolution.

## Status

This repo is a working scaffold, not a production linter yet.

See [Rule status](docs/rule-status.md) for the current rule list and the corresponding ESLint documentation links.
See [Configuration](docs/configuration.md) for `utoo.json` files that can be used in frontend projects.
See [Migrating from ESLint](docs/eslint-migration.md) for the current migration path.

## Prerequisites

Yuku currently tracks Zig nightly. Use a Zig version compatible with the vendored Yuku commit:

```bash
zig version
```

The vendored Yuku `build.zig.zon` currently asks for `0.17.0-dev.224+c166c49b1` or newer.

## Setup

```bash
git submodule update --init --recursive
zig build test -Doptimize=ReleaseFast -j1
zig build run -Doptimize=ReleaseFast -j1 -- test/fixtures/bad.ts
```

Build the binary:

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/utoo-lint src test
```

Build and stage the npm CLI packages:

```bash
./scripts/package-npm.sh
node npm/utoo-lint/bin/utoo-lint.js test/fixtures/bad.ts
```

Local npm install test:

```bash
npm install -g ./npm/@utoo/lint-darwin-arm64
npm install -g ./npm/utoo-lint
utoo-lint test/fixtures/bad.ts
```

## Publishing

GitHub Releases publish binary archives for:

- `utoo-lint-darwin-arm64.tar.gz`
- `utoo-lint-darwin-x64.tar.gz`
- `utoo-lint-linux-arm64.tar.gz`
- `utoo-lint-linux-x64.tar.gz`
- `utoo-lint-windows-x64.zip`

Each archive is uploaded with a matching `.sha256` file.

The npm publishing setup currently supports macOS arm64:

- `npm/utoo-lint` is the public CLI wrapper published as `@utoo/lint`.
- `npm/@utoo/lint-darwin-arm64` is the native binary package published as `@utoo/lint-darwin-arm64`.
- `.github/workflows/release.yml` builds all release archives, uploads them to the GitHub Release, and publishes both npm packages.

Required GitHub repository secret:

```text
NPM_TOKEN
```

Create it from npm as an automation token, then add it in GitHub under `Settings -> Secrets and variables -> Actions`.

Publish from GitHub:

```bash
git tag v0.1.0
git push origin v0.1.0
```

After the workflow succeeds:

```bash
npm install -g @utoo/lint
utoo-lint test/fixtures/bad.ts
```

## CLI

```bash
utoo-lint [options] [file-or-directory ...]
```

If no target is provided, `utoo-lint` scans the current directory. It skips `.git`, `.zig-cache`, `node_modules`, `vendor`, and `zig-out`.

Configuration files:

```json
{
  "$schema": "https://raw.githubusercontent.com/fireairforce/utoo-lint/main/npm/utoo-lint/schema.json",
  "rules": {
    "no-console": "off",
    "no-debugger": "error",
    "@typescript-eslint/no-unused-vars": ["warn"]
  }
}
```

By default, `utoo-lint` reads `utoo.json` or `utoo-lint.json` from the current directory. Use `--config=path/to/utoo.json` for an explicit file or `--no-config` to ignore local config. Rule values may be `off`, `warn`, `error`, `0`, `1`, `2`, booleans, or an ESLint-style array whose first item is the severity.

Start a frontend project from the packaged template:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utoo.json
npx utoo-lint src
```

Rule toggles:

```bash
utoo-lint --no-console=off --no-unused-vars=off src
```

Run only a focused rule set:

```bash
utoo-lint --rules=no-debugger,no-unused-vars,@typescript-eslint/no-unused-vars src
```

Machine-readable output:

```bash
utoo-lint --format=json src
```

JavaScript API:

```js
import { lintFiles } from "@utoo/lint";

const report = lintFiles(["src"], {
  config: "utoo.json",
  rules: ["no-debugger"]
});
```

## Architecture

- `src/root.zig` owns parsing, rule execution, and public API exports.
- `src/core.zig` owns shared lint types, diagnostics, and common helpers.
- `src/rules/root.zig` registers rules and dispatches AST visitor hooks.
- `src/rules/*.zig` contains one lint rule per file.
- `src/main.zig` owns CLI argument parsing, file discovery, and terminal output.
- `vendor/yuku` is pinned as a git submodule so the parser API is reproducible.

The current rule engine deliberately uses Yuku's native flat AST and semantic traverser instead of converting to ESTree. That keeps the first version small and avoids a JS runtime dependency.

## Adding a Rule

Add a new file under `src/rules`, then register it in `src/rules/root.zig`.

For a structural rule, add a check function in the rule file and call it from the matching visitor hook in `BasicVisitor`.

For a scope/symbol rule, add a `run` function in the rule file and call it from `runSemantic`.
