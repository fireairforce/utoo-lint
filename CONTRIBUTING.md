# Contributing

This guide covers local development, rule implementation, packaging, benchmark
charts, and publishing for `utoo-lint`.

## Prerequisites

Yuku currently tracks Zig nightly. Use a Zig version compatible with the
vendored Yuku commit:

```bash
zig version
```

The vendored Yuku `build.zig.zon` currently asks for
`0.17.0-dev.224+c166c49b1` or newer.

Initialize submodules before building:

```bash
git submodule update --init --recursive
```

## Development

Run the test suite:

```bash
zig build test -Doptimize=ReleaseFast -j1
```

Build the CLI:

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/utoo-lint src test
```

Run the CLI against the fixture:

```bash
zig build run -Doptimize=ReleaseFast -j1 -- test/fixtures/bad.ts
```

## Adding a Rule

Add a new file under `src/rules`, then register it in `src/rules/root.zig`.

For a structural rule, add a check function in the rule file and call it from
the matching visitor hook in `BasicVisitor`.

For a scope or symbol rule, add a `run` function in the rule file and call it
from `runSemantic`.

Add focused tests under `tests/rules`, then include the test module from
`tests/all.zig`.

## Benchmarks

The benchmark workspace compares the local `utoo-lint` binary with Oxlint,
Biome, and ESLint on a generated TypeScript corpus using a shared rule set.

```bash
zig build -Doptimize=ReleaseFast
cd benchmarks
npm install
npm run generate
npm run bench
```

The benchmark runner writes machine-readable results to
`benchmarks/results/latest.json`.

Render a shareable chart from the latest benchmark results:

```bash
cd benchmarks
npm run chart
```

`benchmarks/results` is ignored by git, so generated charts do not need to be
cleaned up before committing.

## Packaging

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

The npm package layout is:

- `npm/utoo-lint` is the public CLI wrapper published as `@utoo/lint`.
- `npm/@utoo/lint-darwin-arm64` is published as
  `@utoo/lint-darwin-arm64`.
- `npm/@utoo/lint-darwin-x64` is published as `@utoo/lint-darwin-x64`.
- `npm/@utoo/lint-linux-arm64` is published as `@utoo/lint-linux-arm64`.
- `npm/@utoo/lint-linux-x64` is published as `@utoo/lint-linux-x64`.
- `npm/@utoo/lint-win32-x64` is published as `@utoo/lint-win32-x64`.

## Publishing

GitHub Releases publish binary archives for:

- `utoo-lint-darwin-arm64.tar.gz`
- `utoo-lint-darwin-x64.tar.gz`
- `utoo-lint-linux-arm64.tar.gz`
- `utoo-lint-linux-x64.tar.gz`
- `utoo-lint-windows-x64.zip`

Each archive is uploaded with a matching `.sha256` file.

The release workflow builds all release archives, stages all native npm
packages from the same binaries, uploads the archives to the GitHub Release,
and publishes the native packages before the CLI wrapper.

Required GitHub repository secret:

```text
NPM_TOKEN
```

Create it from npm as an automation token, then add it in GitHub under
`Settings -> Secrets and variables -> Actions`.

Publish from GitHub:

1. Create a new GitHub Release whose tag starts with `v`, for example `v0.1.0`.
2. Publish the release.

The release workflow updates npm package versions from the release tag and
publishes the npm packages.

For a manual run, open the `Release` workflow in GitHub Actions and set
`release_tag` to a `v`-prefixed tag. Enable `publish_npm` when the npm packages
should be published.

After the workflow succeeds:

```bash
npm install -g @utoo/lint
utoo-lint test/fixtures/bad.ts
```
