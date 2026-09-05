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
npm run bench:config-discovery -- --time=1000 --warmup-time=500
```

The config-discovery benchmark models 1,000 lint inputs spread across 100
package directories. It reports both uncached upward searches and the
per-invocation directory cache used by the npm wrapper.

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
## Node API severity-config benchmark

CodSpeed also runs a `CLIEngine` workload modeled after Umi: 1,000 TypeScript
files across 100 package directories with a large flat config containing only
rule severities. Run a smaller local sample with:

```bash
pnpm codspeed:severity-config -- --files=100 --runs=3 --warmups=1
```

## Native flat-config benchmark

CodSpeed also exercises the npm wrapper with 1,000 TypeScript files split
across source and test flat-config groups. The wrapper serializes the config
once and delegates per-file selector resolution to one native process.

Run a smaller local sample with:

```bash
pnpm codspeed:native-flat-config -- --files=100 --time=100 --warmup-time=0
```

## Published website chart

The website uses the archived 2026-08-30 run in
[`public/benchmarks/2026-08-30.json`](../public/benchmarks/2026-08-30.json).
It contains the original samples and commands, but not exact tool versions or
the CPU model. It is a dated snapshot, not a benchmark of the latest release.

Regenerate its English and Chinese SVG images from the repository root:

```bash
node scripts/render-site-benchmark.mjs
```

The published chart uses a linear zero-based scale. New local runs continue to
write to `results/latest.json`; they do not silently replace the published data.
