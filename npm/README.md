# npm packaging

This directory contains the npm CLI wrapper for `@utoo/lint` and the native platform package for `@utoo/lint-darwin-arm64`.

- `@utoo/lint` is the JavaScript CLI package.
- `@utoo/lint-darwin-arm64` contains the native Zig binary for macOS arm64.

Build and stage the local native package:

```bash
./scripts/package-npm.sh
```

Test the wrapper from source:

```bash
node npm/utoo-lint/bin/utoo-lint.js test/fixtures/bad.ts
```

For local global testing:

```bash
npm install -g ./npm/@utoo/lint-darwin-arm64
npm install -g ./npm/utoo-lint
utoo-lint test/fixtures/bad.ts
```

Publishing order:

```bash
npm publish ./npm/@utoo/lint-darwin-arm64 --access public
npm publish ./npm/utoo-lint --access public
```

GitHub Actions uses the same order in `.github/workflows/release.yml`.
