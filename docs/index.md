---
title: utoo-lint
toc: false
hero:
  title: Find code problems faster.
  description: Native-speed linting for the JavaScript projects you already have—without replacing the workflow you already trust.
  actions:
    - text: Read the docs
      link: /configuration
    - text: Open the Playground
      link: /playground/
---

<section class="utlint-home-section utlint-home-section--benchmark" aria-labelledby="utlint-benchmark-title">
  <header class="utlint-home-section-heading">
    <span class="utlint-home-kicker">01 · Benchmark</span>
    <h2 id="utlint-benchmark-title">About 70× faster than ESLint.</h2>
    <p>
      Measured with the same generated TypeScript corpus and the same 12 shared
      rules. Every sample starts a fresh CLI process; results vary by project
      and machine.
    </p>
    <a class="utlint-home-text-link" href="https://github.com/utooland/utoo-lint/tree/main/benchmarks">
      See the methodology and run it yourself <span aria-hidden="true">→</span>
    </a>
  </header>
  <figure class="utlint-benchmark-panel" aria-labelledby="utlint-benchmark-caption">
    <header>
      <div>
        <span>Repository benchmark</span>
        <strong>Relative wall-clock time</strong>
      </div>
      <span>Lower is better</span>
    </header>
    <div class="utlint-benchmark-chart">
      <div class="utlint-benchmark-row utlint-benchmark-row--utoo">
        <span>utoo-lint</span><i aria-hidden="true"></i><strong>1×</strong>
      </div>
      <div class="utlint-benchmark-row utlint-benchmark-row--eslint">
        <span>ESLint</span><i aria-hidden="true"></i><strong>~70×</strong>
      </div>
    </div>
    <figcaption id="utlint-benchmark-caption">
      100 TypeScript files · 12 shared rules · fresh process per sample · rounded from repeated runs
    </figcaption>
  </figure>
</section>

<section class="utlint-home-section utlint-home-section--migration" aria-labelledby="utlint-migration-title">
  <header class="utlint-home-section-heading">
    <span class="utlint-home-kicker">02 · Migration</span>
    <h2 id="utlint-migration-title">Replace ESLint without the big-bang rewrite.</h2>
    <p>
      Migration is deliberately incremental. Generate a report first, move the
      rules utoo-lint implements natively, and keep processors or custom plugin
      behavior where ESLint still owns the job.
    </p>
  </header>
  <div class="utlint-migration-boundary">
    <article>
      <h3>Move now</h3>
      <p>Compatible rule IDs, severities, file patterns and serializable flat-config entries.</p>
      <code>utoo-lint migrate eslint --print</code>
    </article>
    <article>
      <h3>Keep in ESLint</h3>
      <p>Processors, project-specific plugins and type-service workflows that are not covered yet.</p>
      <a href="/rule-status">Check rule coverage <span aria-hidden="true">→</span></a>
    </article>
    <article>
      <h3>Verify in CI</h3>
      <p>Run both tools, compare JSON diagnostics, then retire ESLint coverage rule by rule.</p>
      <a href="/eslint-migration">Open the migration guide <span aria-hidden="true">→</span></a>
    </article>
  </div>
</section>

<section class="utlint-home-section utlint-home-section--architecture" aria-labelledby="utlint-architecture-title">
  <header class="utlint-home-section-heading">
    <span class="utlint-home-kicker">03 · Runtime</span>
    <h2 id="utlint-architecture-title">One core. Native, Node and WebAssembly.</h2>
    <p>
      The Node wrapper handles trusted TypeScript configuration and project
      discovery. The Zig engine receives a serializable rule map. The
      freestanding WebAssembly build lints source already held in memory.
    </p>
  </header>
  <ol class="utlint-engine-pipeline" aria-label="utoo-lint configuration pipeline">
    <li><strong>utlint.config.ts</strong><span>Typed authoring</span></li>
    <li><strong>Node wrapper</strong><span>Resolve files and config</span></li>
    <li><strong>Zig engine</strong><span>Parse, analyze and fix</span></li>
    <li><strong>CLI or WebAssembly</strong><span>Repository and browser</span></li>
  </ol>
  <div class="utlint-surface-grid">
    <article>
      <h3>Native CLI</h3>
      <p>Traverse a repository, apply project config and write supported fixes.</p>
    </article>
    <article>
      <h3>Typed configuration</h3>
      <p>Import presets and keep editor completion in a trusted Node entry point.</p>
    </article>
    <article>
      <h3>Browser WebAssembly</h3>
      <p>Reuse one in-memory linter without sending source to a remote service.</p>
    </article>
  </div>
</section>

<aside class="utlint-home-cta" aria-labelledby="utlint-cta-title">
  <div>
    <span class="utlint-home-kicker">Try it locally</span>
    <h2 id="utlint-cta-title">Put your own code through it.</h2>
    <p>
      The Playground uses the WebAssembly build locally in your browser. Your
      code is not uploaded to a lint service.
    </p>
  </div>
  <nav class="utlint-home-cta-actions" aria-label="Get started">
    <NativeLink href="/playground/" className="utlint-home-button utlint-home-button--primary">Open the Playground</NativeLink>
    <a href="/configuration" class="utlint-home-button utlint-home-button--secondary">Read the docs</a>
  </nav>
</aside>
