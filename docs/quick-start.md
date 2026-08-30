# Quick Start

Install `utoo-lint`, run it on an existing JavaScript or TypeScript project,
then add a typed project config when you are ready to choose rules and files.

## Requirements

The npm package requires Node.js 20 or later. It installs a prebuilt native
binary for supported macOS, Linux, and Windows platforms, so using the package
does not require a Zig toolchain.

## Install

Use the package manager already used by your project:

```bash
# pnpm
pnpm add -D @utoo/lint

# npm
npm install --save-dev @utoo/lint

# utoo
ut install @utoo/lint -D
```

## Run Your First Check

Point the CLI at a source directory. Without a config file, utoo-lint uses its
built-in default rules.

```bash
pnpm exec utoo-lint src
```

With npm, use `npx utoo-lint src`. With utoo, use `utx @utoo/lint src`.

## Add a Typed Config

Create `utlint.config.ts` in the project root. The frontend preset provides a
practical starting point for JavaScript, TypeScript, React, imports, and JSX
accessibility rules.

```ts
import { defineConfig } from "@utoo/lint/config";
import frontend from "@utoo/lint/configs/frontend";

export default defineConfig({
  ...frontend,
  ignores: [...frontend.ignores, ".next", "storybook-static"],
  rules: {
    ...frontend.rules,
    "no-console": "off"
  }
});
```

The preset includes its own `files` patterns, so the CLI can discover source
files without a positional target:

```bash
pnpm exec utoo-lint
```

See [Configuration](/configuration) for flat config arrays, static JSON
config, global ignores, rule options, and precedence.

## Add Package Scripts

Put repeatable lint commands in `package.json`:

```json
{
  "scripts": {
    "lint": "utoo-lint src",
    "lint:fix": "utoo-lint --fix src"
  }
}
```

Run them with your package manager, for example `pnpm lint` and
`pnpm lint:fix`.

## Next Steps

- Review the complete [rule coverage](/rule-status).
- Move an existing project with the [ESLint migration guide](/eslint-migration).
- Learn how to document intentional exceptions with [suppression comments](/suppressions).
- Try one file without installing anything in the [Playground](/playground/).
