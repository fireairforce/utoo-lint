# utoo-lint benchmark

This directory benchmarks the current local `@utoo/lint` binary against Oxlint,
Biome, and ESLint on the same generated TypeScript corpus.

## Setup

From the repository root:

```bash
zig build -Doptimize=ReleaseFast
cd benchmarks
npm install
npm run generate
npm run bench
```

The benchmark runner writes machine-readable output to `results/latest.json`.

## Commands

```bash
npm run generate -- --files=2000 --statements=40
npm run bench -- --runs=10 --warmups=3
```

The default `utoo-lint` command is `../zig-out/bin/utoo-lint fixtures/src`.
Override it with:

```bash
UTOO_LINT_BIN=/path/to/utoo-lint npm run bench
```

Skip ESLint when you only want the native linter comparison:

```bash
npm run bench -- --skip-eslint
```

## Notes

- The generated corpus is designed to be valid TypeScript with no intentional
  diagnostics. This keeps benchmark time focused on traversal and rule
  execution instead of terminal output.
- The tools do not have identical rule sets. Treat the result as practical CLI
  throughput, not proof that all tools performed identical semantic work.
- The runner measures wall-clock time for fresh CLI processes. Editor daemon
  behavior, caches, and type-aware ESLint rules are intentionally out of scope.
