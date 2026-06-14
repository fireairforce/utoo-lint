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
import { CLIEngine, ESLint, lintFiles, lintText, resolveBinary, run, runFishlint } from "@utoo/lint";

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

const cli = new CLIEngine({
  useEslintrc: false,
  baseConfig: {
    rules: {
      "no-debugger": "error"
    }
  }
});
console.log(cli.executeOnFiles(["src"]).results);
```

CommonJS scripts can use the same surface through `require()`:

```js
const { ESLint, lintFiles } = require("@utoo/lint");
```

The CommonJS entry is kept behaviorally aligned with the ESM API, including
the fishlint wrapper and per-file flat config handling.

`lintFiles()` and `lintText()` return an object with `files`, `filePaths`,
`diagnostics`, and `exitCode`. Each diagnostic includes `filePath`, `line`,
`column`, `severity`, `message`, and `ruleId`, with disabled per-file rules
filtered from the diagnostics. The `ESLint` export is an alias for `UtooLint`
and supports the common `lintFiles()`, `lintText()`,
`loadFormatter()`, `isPathIgnored()`, and `calculateConfigForFile()` methods for
low-friction replacements. It also provides ESLint-compatible `version`,
`outputFixes()`, `getErrorResults()`, and `getRulesMetaForResults()` surfaces.
Rule meta includes best-effort `docs.url` values for common ESLint-compatible
rule IDs. `loadFormatter()` and `CLIEngine#getFormatter()` support `json`,
`json-with-metadata`, `compact`, `unix`, and the native text formatter shape.
`lintFiles()` returns absolute `filePaths` and diagnostic `filePath` values,
includes empty results for checked files with no messages, and filters inputs
with the same ignore rules.
`lintText()` applies those ignore rules to the supplied `filePath` and uses the
same config discovery as file linting unless `noConfig` is set. Raw
`lintText()` reports use the supplied `filePath` for both `filePaths` and
diagnostics.
`isPathIgnored()` reads default `.eslintignore` entries plus `ignorePath`,
`ignorePatterns`, `noIgnore`, and `baseConfig`/`overrideConfig` ignore entries.
`calculateConfigForFile()` and `CLIEngine#getConfigForFile()` merge
`baseConfig`, default `utoo.json` or `utoo-lint.json` files, explicit
`overrideConfigFile`, and `overrideConfig` rules. `baseConfig` and
`overrideConfig` may be objects or flat config arrays; when a file path is
provided, flat config `files` and `ignores` entries are applied before merging.
ESLint-compatible results use those calculated rule severities for `messages`,
`errorCount`, and `warningCount`, including per-file flat config matches. The
JS API filters diagnostics for rules disabled by the matched file config. The
native run keeps rules enabled when any matched flat config entry may need them,
so later `off` entries do not suppress diagnostics for other files. Raw
`diagnostics` use the same per-file severity and disabled-rule filtering. The
`CLIEngine` export
provides a synchronous legacy facade for older ESLint integrations.
`CLIEngine#executeOnText()` accepts a string path or an options object with
`filePath`, `filename`, and text lint options.
`ESLint` and `CLIEngine` constructor options also accept `quiet: true` to return
only error messages, matching ESLint's warning filtering behavior.
`warnIgnored: false` suppresses warnings for explicit ignored file paths and
skips ignored `lintText()` inputs. `errorOnUnmatchedPattern: false` skips
explicit missing file paths. Set
`UTOO_LINT_BIN=/path/to/utoo-lint` to force the JS API and CLI wrapper to use a
specific native binary during local development.

The package also installs a `fishlint` compatibility command for projects that
currently run `fishlint eslint ...`. It supports the common eslint subcommand
shape, forwards `--config` and `-c`, maps `--glob` values to native lint
targets, and normalizes split value flags such as `--format json`, `-f json`,
`--threads 4`, and `--rules no-debugger`. `--no-eslintrc` maps to native
`--no-config`, and `--no-eslintrc=true` is accepted for compatibility.
`json-with-metadata` emits the native JSON report with a `metadata.rulesMeta`
section. Other non-JSON ESLint formatter names are accepted and use native text
output. `--rule`
accepts JSON objects such as
`{"no-console":"warn"}` and simple `rule: severity` pairs, merging them into the
selected utoo-lint config for the run. It ignores fishlint-only setup/debug
flags. `--ext` is accepted for compatibility; native directory traversal already
filters to supported JavaScript and TypeScript extensions. ESLint cache controls and
other cache flags are consumed for compatibility because utoo-lint does not keep
an ESLint-style result cache. The wrapper applies ESLint-style warning exit-code
semantics, including `--max-warnings`. ESLint runtime config flags such as
`--env`, `-E`, `--global`, `--parser`, `--parser-options`, `--plugin`, and
ignore-pattern flags are accepted so existing wrapper scripts do not pass them
as file targets. The wrapper applies simple `.eslintignore`, `--ignore-path`,
and `--ignore-pattern` filters such as `dist/**` to explicit and `--glob`
targets before invoking native lint, including `**/*.js` globstar patterns and
`!pattern` negation entries.
`--no-ignore` and `--no-ignore=true` disable those wrapper-side ignore filters.
`--no-error-on-unmatched-pattern` and `--no-error-on-unmatched-pattern=true` skip
missing explicit and `--glob` targets before invoking native lint. `--quiet`
and `--quiet=true` filter warnings from compatibility output. Explicit ignored
file paths emit ESLint-style warnings unless `--no-warn-ignored` or
`--no-warn-ignored=true` is set.
Fix controls such as `--fix`, `--fix-dry-run`, and `--fix-type` are accepted
with a warning because utoo-lint does not apply fixes yet.
Display and reporting controls such as `--color`, `--no-color`, `--stats`,
`--stats=true`, and `--no-warn-ignored` are accepted for the same reason.
`--output-file` and `-o` write the native output to the requested report file.
`--stdin` reads source from standard input, and `--stdin-filename` controls the
path shown in output.
`--print-config` prints the selected utoo-lint JSON configuration for migration
debugging.

The package also exposes an `eslint` compatibility bin that routes directly
through the same wrapper, so package scripts such as `eslint src -f json` can be
tested without adding the `fishlint eslint` prefix.

```bash
npx fishlint eslint --disable-setup --config utoo.json --ext .js,.ts --glob src
npx eslint --config utoo.json --ext .js,.ts src
```

For programmatic replacements, `runFishlint()` invokes the same compatibility
wrapper as the `fishlint` bin, including wrapper-side ignore filtering, quiet
output, max-warning exit semantics, stdin handling through `options.input`, and
delegated commands.

For non-eslint fishlint commands, the compatibility command delegates to
project-local tools when they are installed: `fishlint format` runs `prettier`,
`fishlint stylelint` runs `stylelint`, `fishlint commitlint` runs `commitlint`,
and `fishlint projectlint` runs `projectlint`. This keeps existing scripts
working without treating those tools as native `utoo-lint` checks. Delegated
commands also consume fishlint-only setup and verbose flags, including
`--disable-setup=true` and similar value forms.
`fishlint format` defaults to `prettier --write`, but keeps explicit prettier
mode flags such as `--check`, `--list-different`, and `--debug-check` instead
of adding `--write`.
`fishlint commitlint -E=GIT_PARAMS` is normalized like `--env GIT_PARAMS`,
falling back to `--edit` when the environment variable is not set.
Default delegated targets are still added when the command only contains
configuration value flags such as `fishlint format --config .prettierrc`.
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
