# utoo-lint benchmark

This directory benchmarks the current local `@utoo/lint` binary against Oxlint,
Biome, and ESLint on the same generated TypeScript corpus and the same shared
lint rule set.

## Setup

From the repository root:

```bash
zig build -Doptimize=ReleaseFast
cd benchmarks
npm install
npm run generate
npm run bench
```

The benchmark runner writes machine-readable output to `results/latest.json`,
including the target file count and the shared rule list used for that run.

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
- The runner keeps tool comparisons aligned by applying the same target path to
  every tool and enabling only the shared rules defined in
  `scripts/shared-rules.mjs`.
- The current shared rule set is: `no-const-assign`,
  `no-empty-character-class`, `no-empty-pattern`, `no-unsafe-finally`,
  `use-isnan`, `valid-typeof`, `no-debugger`, `no-duplicate-case`,
  `no-fallthrough`, `no-global-assign`, `no-import-assign`, and
  `no-unsafe-negation`.
- The runner measures wall-clock time for fresh CLI processes. Editor daemon
  behavior, caches, and type-aware ESLint rules are intentionally out of scope.
