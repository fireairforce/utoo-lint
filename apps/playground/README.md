# utoo-lint Playground

The Playground runs utoo-lint entirely in the browser. It uses the public
EVJS packages, Utoopack, Monaco Editor, a Web Worker, and the workspace
`@utoo/lint-wasm` package. Its AST inspector uses the public
`@yuku-parser/wasm` 0.9.1 package, matching the Yuku revision vendored by
utoo-lint.

No `@alipay/*` package, private registry, internal runtime, or server process
is required. EVJS discovers the root `src/pages/page.tsx` as a CSR SPA, and
the static deployment adapter emits a complete site under `dist/client`.

## Develop

From the repository root, install dependencies with Node.js 20 or newer and
pnpm 10:

```bash
pnpm install --frozen-lockfile
```

The versioned WebAssembly artifact is downloaded from the matching GitHub
release and intentionally is not checked into Git. The staging script verifies
its pinned SHA-256 before starting the Playground:

```bash
pnpm playground:dev
```

The root script stages the v0.3.0 artifact as
`npm/@utoo/lint-wasm/utoo-lint.wasm` before starting EVJS. The Utoopack
development URL is printed in the terminal.

## Verify and build

```bash
pnpm playground:typecheck
pnpm --filter @utoo/lint-playground inspect
pnpm playground:build
```

The production build runs a deployment audit after `ev build`. It checks that
the output is a complete static deployment, contains valid lint and parser
WASM assets,
requires no server, loads no remote runtime assets, and contains no known
internal registry or release-chain markers.

Deploy `apps/playground/dist/client` at the root of a static origin. The
generated `_redirects` file provides the SPA fallback on hosts such as
Cloudflare Pages and Netlify. The current EVJS output uses root-relative asset
URLs, so repository-subpath hosting needs an origin rewrite or a dedicated
domain.

The production Playground is deployed to
[`utlint.umijs.org`](https://utlint.umijs.org/).

## Runtime boundaries

- Linting and autofix run in a long-lived Web Worker.
- The worker loads the freestanding WASM module once and reuses it.
- AST parsing runs in a separate Worker and starts only after opening the AST
  inspector.
- Both WASM modules are bundled locally; the page makes no parser CDN request.
- The Playground lints one in-memory JavaScript, TypeScript, JSX, or TSX file.
- Rules that require filesystem access are reported as skipped.
- Monaco is bundled locally; the page does not depend on a CDN.
