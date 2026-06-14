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
import { ESLint, lintFiles, lintText, resolveBinary, run, runFishlint } from "@utoo/lint";

const report = lintFiles(["src", "test"], {
  config: "utoo.json",
  rules: ["no-debugger", "@typescript-eslint/no-unused-vars"]
});

console.log(report.diagnostics);
console.log(resolveBinary());
console.log(run(["--help"]).stdout);
console.log(runFishlint(["eslint", "--disable-setup", "--glob", "src"]).status);

const textReport = lintText("debugger;\n", {
  filePath: "inline.js",
  rules: ["no-debugger"]
});
console.log(textReport.diagnostics);

const eslint = new ESLint({
  useEslintrc: false,
  overrideConfig: {
    rules: {
      "no-debugger": "warn"
    }
  }
});
const results = await eslint.lintText("debugger;\n", { filePath: "inline.js" });
console.log(results[0].messages);
console.log(ESLint.version);
console.log(ESLint.getErrorResults(results));
```

`lintFiles()` and `lintText()` return an object with `files`, `filePaths`,
`diagnostics`, and `exitCode`. Each diagnostic includes `filePath`, `line`,
`column`, `severity`, `message`, and `ruleId`. The `ESLint` export is an alias
for `UtooLint` and supports the common `lintFiles()`, `lintText()`,
`loadFormatter()`, `isPathIgnored()`, and `calculateConfigForFile()` methods for
low-friction replacements. It also provides ESLint-compatible `version`,
`outputFixes()`, `getErrorResults()`, and `getRulesMetaForResults()` surfaces.
`lintFiles()` returns absolute `filePath` values and includes empty results for
checked files with no messages. Set
`UTOO_LINT_BIN=/path/to/utoo-lint` to force the JS API and CLI wrapper to use a
specific native binary during local development.

The package also installs a `fishlint` compatibility command for projects that
currently run `fishlint eslint ...`. It supports the common eslint subcommand
shape, forwards `--config`, maps `--glob` values to native lint targets, and
normalizes split value flags such as `--format json`, `-f json`, `--threads 4`,
and `--rules no-debugger`. It ignores fishlint-only setup/debug flags. `--ext`
is accepted for compatibility; native directory traversal already filters to
supported JavaScript and TypeScript extensions.

```bash
npx fishlint eslint --disable-setup --config utoo.json --ext .js,.ts --glob src
```

For programmatic replacements, `runFishlint()` applies the same argument
translation before invoking the native binary.

For non-eslint fishlint commands, the compatibility command delegates to
project-local tools when they are installed: `fishlint format` runs `prettier`,
`fishlint stylelint` runs `stylelint`, `fishlint commitlint` runs `commitlint`,
and `fishlint projectlint` runs `projectlint`. This keeps existing scripts
working without treating those tools as native `utoo-lint` checks.
`fishlint setup` and `fishlint setuplint` are accepted as no-ops so existing
install hooks do not fail after replacing the package.

`fishlint-lint-staged` is also provided for generated fishlint pre-commit hooks.
If a project has its own `lint-staged` install, the wrapper delegates to it.
Otherwise it lints staged JavaScript and TypeScript files directly with
`utoo-lint`.

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
