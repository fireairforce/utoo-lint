# WebAssembly

`@utoo/lint-wasm` is the browser-ready, ESM-only WebAssembly distribution of
utoo-lint. It is designed for lint playgrounds, editor integrations, Web
Workers, and Node ESM programs that lint source already held in memory.

The WebAssembly module is freestanding: it imports neither WASI nor a host
filesystem API.

## Installation

```bash
pnpm add @utoo/lint-wasm
```

The package includes its JavaScript loader, TypeScript declarations, and the
`utoo-lint.wasm` binary. A bundler or asset server must preserve the emitted
Wasm asset when deploying a browser application.

## Browser ESM

Create one linter and reuse it across edits:

```js
import { createUtooLint } from "@utoo/lint-wasm";

const linter = await createUtooLint();
const report = linter.lint("const answer = 42; debugger;", {
  filePath: "playground.ts",
  rules: {
    "no-debugger": "error",
    "no-unused-vars": "warn"
  }
});

for (const diagnostic of report.diagnostics) {
  console.log(diagnostic.ruleId, diagnostic.message, diagnostic.range);
}
```

`createUtooLint()` loads and instantiates the Wasm module asynchronously. The
returned instance's `lint()` and `lintAndFix()` methods are synchronous, which
makes reuse inexpensive but also means an interactive UI should call them from
a Web Worker.

## Node ESM

The async convenience functions lazily create and reuse a default instance:

```js
import { lint, lintAndFix } from "@utoo/lint-wasm";

const report = await lint("debugger;", {
  filePath: "snippet.js",
  rules: { "no-debugger": "error" }
});

const fixed = await lintAndFix("const value = 1;;;", {
  filePath: "snippet.js",
  rules: { "no-extra-semi": "error" }
});

console.log(report.diagnostics);
console.log(fixed.output);
```

Use `createUtooLint()` when an application needs an explicit instance or wants
to supply its own Wasm URL, response, bytes, compiled module, or instance:

```js
const linter = await createUtooLint({
  wasm: new URL("./utoo-lint.wasm", import.meta.url)
});
```

## In-Memory Execution Model

Each call accepts one source string plus options. `filePath` is a virtual path:
its extension selects JavaScript, TypeScript, JSX, or TSX parsing, but the file
is never read or written. The Wasm build does not discover project config,
expand globs, traverse directories, resolve modules, or inspect dependencies.

`lintAndFix()` returns the fixed source in `output`; it does not modify a file.
Diagnostics from that call describe the final output and set
`diagnosticsSource` to `"output"`. Plain `lint()` diagnostics describe the
input. Diagnostic and fix `range` values are UTF-16 offsets, so they can be
used directly with JavaScript strings and browser editor APIs.

Suppressed findings are returned separately in `suppressedDiagnostics`.

## Rule Selection

Omitting `rules` uses utoo-lint's built-in default rule set:

```js
linter.lint(source, { filePath: "input.js" });
```

Providing a `rules` object starts from all lint rules disabled and enables only
the entries in that object. In particular, an empty object disables every
configurable lint rule:

```js
linter.lint(source, { filePath: "input.js", rules: {} });
```

Parser diagnostics can still be returned when `rules` is empty because parsing
is required to process the source.

Rules that need real project I/O cannot execute in the freestanding module. If
one of these rules is enabled, the call succeeds and its rule ID is included in
`skippedRules` rather than silently pretending that the project check ran. The
current filesystem-backed set is:

- `@alipay/ant/no-phantom-dependencies`
- `@alipay/ant/prefer-import-from-stdlib`
- `import/default`
- `import/export`
- `import/named`
- `import/namespace`
- `import/no-cycle`
- `import/no-named-as-default`
- `import/no-named-as-default-member`
- `import/no-unresolved`

Check `skippedRules` on every result before presenting a Playground run as
equivalent to project-wide CLI linting.

## Playground Architecture

Keep the initialized linter inside a long-lived Web Worker. Send only the
latest source and options to it, and discard stale responses in the UI when a
newer edit has already been queued.

```js
// lint.worker.js
import { createUtooLint } from "@utoo/lint-wasm";

const linterPromise = createUtooLint();

self.onmessage = async ({ data }) => {
  const { id, source, options, fix = false } = data;

  try {
    const linter = await linterPromise;
    const result = fix
      ? linter.lintAndFix(source, options)
      : linter.lint(source, options);
    self.postMessage({ id, result });
  } catch (error) {
    self.postMessage({
      id,
      error: {
        name: error.name,
        code: error.code,
        message: error.message,
        ruleId: error.ruleId
      }
    });
  }
};
```

Debounce editor events on the main thread and attach a monotonically
increasing `id` to each request. This keeps lint execution off the rendering
thread without repeatedly compiling the Wasm module.

## Build and Test

Initialize the Yuku submodule and use the Zig version documented in
`CONTRIBUTING.md`, then install workspace dependencies:

```bash
git submodule update --init --recursive
pnpm install
```

Build the raw freestanding module:

```bash
pnpm build:wasm
```

The output is `zig-out/bin/utoo-lint.wasm`. To build it and copy it into the npm
package directory, run:

```bash
pnpm package:wasm
```

Run the raw ABI and JavaScript wrapper tests, followed by the staged package
and declaration tests:

```bash
pnpm test:wasm
pnpm --dir npm/@utoo/lint-wasm test
pnpm --dir npm/@utoo/lint-wasm test:types
```

The ABI test also verifies that the module has no imports and exposes the
expected memory, allocator, ABI version, and lint entry points.
