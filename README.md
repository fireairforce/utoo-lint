# utoo-lint

![utoo-lint logo](assets/utoo-lint-logo.svg)

`@utoo/lint` is an experimental JavaScript and TypeScript linter written in Zig.
It uses [`yuku`](https://github.com/yuku-toolchain/yuku) (GitHub: https://github.com/yuku-toolchain/yuku) for parsing, AST traversal, scope tracking, and symbol resolution.

## Status

This repo is a working scaffold, not a production linter yet. The first rules are:

- `curly`
- `dot-notation`
- `default-case`
- `default-case-last`
- `eol-last`
- `for-direction`
- `getter-return`
- `guard-for-in`
- `linebreak-style`
- `new-parens`
- `no-async-promise-executor`
- `no-alert`
- `no-array-constructor`
- `no-await-in-loop`
- `no-bitwise`
- `no-buffer-constructor`
- `no-caller`
- `no-case-declarations`
- `no-class-assign`
- `no-cond-assign`
- `no-compare-neg-zero`
- `no-constant-condition`
- `no-const-assign`
- `no-control-regex`
- `no-console`
- `no-constructor-return`
- `no-comma-operator`
- `no-continue`
- `no-debugger`
- `no-duplicate-imports`
- `no-dupe-args`
- `no-dupe-class-members`
- `no-dupe-else-if`
- `no-dupe-keys`
- `no-delete-var`
- `no-div-regex`
- `no-duplicate-case`
- `no-empty`
- `no-empty-block-statements`
- `no-empty-character-class`
- `no-empty-function`
- `no-empty-pattern`
- `no-empty-static-block`
- `no-else-return`
- `no-eq-null`
- `no-eval`
- `no-ex-assign`
- `no-extend-native`
- `no-extra-bind`
- `no-extra-label`
- `no-extra-semi`
- `no-extra-boolean-cast`
- `no-floating-decimal`
- `no-for-in`
- `no-func-assign`
- `no-global-assign`
- `no-global-is-finite`
- `no-global-is-nan`
- `no-implicit-coercion`
- `no-implied-eval`
- `no-import-assign`
- `no-inline-comments`
- `no-irregular-whitespace`
- `no-iterator`
- `no-label-var`
- `no-labels`
- `no-lone-blocks`
- `no-lonely-if`
- `no-loss-of-precision`
- `no-mixed-spaces-and-tabs`
- `no-multi-assign`
- `no-multi-spaces`
- `no-multi-str`
- `no-multiple-empty-lines`
- `no-nonoctal-decimal-escape`
- `no-new`
- `no-nested-ternary`
- `no-negated-condition`
- `no-new-native-nonconstructor`
- `no-obj-calls`
- `no-new-func`
- `no-new-require`
- `no-new-object`
- `no-new-symbol`
- `no-new-wrappers`
- `no-octal`
- `no-octal-escape`
- `no-object-constructor`
- `no-path-concat`
- `no-plusplus`
- `no-promise-executor-return`
- `no-proto`
- `no-process-env`
- `no-process-exit`
- `no-prototype-builtins`
- `no-regex-spaces`
- `no-return-await`
- `no-return-assign`
- `no-useless-return`
- `no-script-url`
- `no-self-assign`
- `no-self-compare`
- `no-setter-return`
- `no-shadow-restricted-names`
- `no-sequences`
- `no-sparse-arrays`
- `no-ternary`
- `no-template-curly-in-string`
- `no-throw-literal`
- `no-tabs`
- `no-trailing-spaces`
- `no-unreachable`
- `no-undef-init`
- `unicode-bom`
- `no-unneeded-ternary`
- `no-unused-labels`
- `no-unsafe-finally`
- `no-unsafe-negation`
- `no-useless-computed-key`
- `no-useless-call`
- `no-useless-concat`
- `no-useless-constructor`
- `no-useless-catch`
- `no-useless-rename`
- `no-warning-comments`
- `no-void`
- `no-with`
- `no-var`
- `operator-assignment`
- `eqeqeq`
- `no-unused-vars`
- `no-undef`
- `prefer-exponentiation-operator`
- `prefer-regex-literals`
- `prefer-template`
- `radix`
- `require-yield`
- `spaced-comment`
- `symbol-description`
- `use-isnan`
- `valid-typeof`
- `yoda`
- `parse` diagnostics from Yuku, including semantic early errors by default

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

Rule toggles:

```bash
utoo-lint --no-console=off --no-unused-vars=off src
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
