# npm packaging

This directory contains the npm CLI wrapper for `@utoo/lint` and the native platform packages.

- `@utoo/lint` is the JavaScript CLI package.
- `@utoo/lint-darwin-arm64` contains the native Zig binary for macOS arm64.
- `@utoo/lint-darwin-x64` contains the native Zig binary for macOS x64.
- `@utoo/lint-linux-arm64` contains the native Zig binary for Linux arm64.
- `@utoo/lint-linux-x64` contains the native Zig binary for Linux x64.
- `@utoo/lint-win32-x64` contains the native Zig binary for Windows x64.

The CLI package also exposes a small ESM API:

```js
import { lintFiles, resolveBinary, run } from "@utoo/lint";

const report = lintFiles(["src", "test"], {
  config: "utoo.json",
  rules: ["no-debugger", "@typescript-eslint/no-unused-vars"]
});

console.log(report.diagnostics);
console.log(resolveBinary());
console.log(run(["--help"]).stdout);
```

`lintFiles()` returns `{ files, diagnostics, exitCode }`. Each diagnostic includes
`filePath`, `line`, `column`, `severity`, `message`, and `ruleId`. Set
`UTOO_LINT_BIN=/path/to/utoo-lint` to force the JS API and CLI wrapper to use a
specific native binary during local development.

Use the packaged frontend config in an app:

```bash
cp node_modules/@utoo/lint/configs/frontend.json utoo.json
npx utoo-lint src
```

The package also ships `schema.json`, which the frontend config references through
its `$schema` field for editor validation.

Build and stage the local native package for the current host:

```bash
./scripts/package-npm.sh
```

Test the wrapper from source:

```bash
node npm/utoo-lint/bin/utoo-lint.js test/fixtures/bad.ts
```

For local global testing:

```bash
npm install -g ./npm/@utoo/lint-darwin-arm64 # replace with the current host package
npm install -g ./npm/utoo-lint
utoo-lint test/fixtures/bad.ts
```

Publishing order:

```bash
for package_dir in dist/native-packages/npm/@utoo/lint-*; do
  npm publish "${package_dir}" --access public
done
npm publish ./npm/utoo-lint --access public
```

GitHub Actions stages the native package directories from the release matrix and uses the same order in `.github/workflows/release.yml`.
