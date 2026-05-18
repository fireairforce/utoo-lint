# utoo-lint

`utoo-lint` is an experimental JavaScript and TypeScript linter written in Zig.
It uses [`yuku`](https://github.com/yuku-toolchain/yuku) for parsing, AST traversal, scope tracking, and symbol resolution.

## Status

This repo is a working scaffold, not a production linter yet. The first rules are:

- `no-console`
- `no-debugger`
- `no-var`
- `eqeqeq`
- `no-unused-vars`
- `no-undef`
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
zig build test
zig build run -- test/fixtures/bad.ts
```

Build the binary:

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/utoo-lint src test
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

- `src/root.zig` owns the lint engine and rule implementations.
- `src/main.zig` owns CLI argument parsing, file discovery, and terminal output.
- `vendor/yuku` is pinned as a git submodule so the parser API is reproducible.

The current rule engine deliberately uses Yuku's native flat AST and semantic traverser instead of converting to ESTree. That keeps the first version small and avoids a JS runtime dependency.
