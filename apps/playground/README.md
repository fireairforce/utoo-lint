# utoo-lint Playground

The Playground runs utoo-lint entirely in the browser. It uses the public
EVJS packages, Utoopack, Monaco Editor, a Web Worker, and the workspace
`@utoo/lint-wasm` package.

No `@alipay/*` package, private registry, internal runtime, or server process
is required. EVJS discovers the root `src/pages/page.tsx` as a CSR SPA, and
the static deployment adapter emits a complete site under `dist/client`.

## Develop

From the repository root, install dependencies with Node.js 20 or newer and
pnpm 10:

```bash
pnpm install --frozen-lockfile
```

The WebAssembly artifact is generated from the Zig source and intentionally
is not checked into Git. Use the Zig version declared in `build.zig.zon`, then
start the Playground:

```bash
pnpm playground:dev
```

The root script stages `npm/@utoo/lint-wasm/utoo-lint.wasm` before starting
EVJS. The Utoopack development URL is printed in the terminal.

## Verify and build

```bash
pnpm playground:typecheck
pnpm --filter @utoo/lint-playground inspect
pnpm playground:build
```

The production build runs a deployment audit after `ev build`. It checks that
the output is a complete static deployment, contains one valid WASM asset,
requires no server, loads no remote runtime assets, and contains no known
internal registry or release-chain markers.

Deploy `apps/playground/dist/client` at the root of a static origin. The
generated `_redirects` file provides the SPA fallback on hosts such as
Cloudflare Pages and Netlify. The current EVJS output uses root-relative asset
URLs, so repository-subpath hosting needs an origin rewrite or a dedicated
domain.

## Runtime boundaries

- Linting and autofix run in a long-lived Web Worker.
- The worker loads the freestanding WASM module once and reuses it.
- The Playground lints one in-memory JavaScript, TypeScript, JSX, or TSX file.
- Rules that require filesystem access are reported as skipped.
- Monaco is bundled locally; the page does not depend on a CDN.
