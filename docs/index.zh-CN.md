---
title: utoo-lint 中文文档
toc: false
hero:
  title: 更快地发现代码问题。
  description: 为现有 JavaScript 工程带来原生级检查速度，不用推翻你已经熟悉的工作流。
  actions:
    - text: 阅读文档
      link: /zh-CN/configuration
    - text: 打开 Playground
      link: /playground/
---

<section class="utlint-home-section utlint-home-section--benchmark" aria-labelledby="utlint-benchmark-title">
  <header class="utlint-home-section-heading">
    <span class="utlint-home-kicker">01 · 性能基准</span>
    <h2 id="utlint-benchmark-title">冷启动只需 8.35 毫秒。</h2>
    <p>
      仓库中的基准测试会针对同一批生成的 TypeScript 文件和相同的 12 条
      Lint 规则，每次启动一个全新的进程。以下结果于 2026 年 6 月 13 日在
      Darwin arm64 环境中记录。
    </p>
    <a class="utlint-home-text-link" href="https://github.com/utooland/utoo-lint/tree/main/benchmarks">
      阅读测试方法并亲自运行 <span aria-hidden="true">→</span>
    </a>
  </header>
  <figure class="utlint-benchmark-panel" aria-labelledby="utlint-benchmark-caption">
    <header>
      <div>
        <span>每次启动新的 CLI 进程</span>
        <strong>实际耗时中位数</strong>
      </div>
      <span>数值越低越好</span>
    </header>
    <div class="utlint-benchmark-chart">
      <div class="utlint-benchmark-row utlint-benchmark-row--utoo">
        <span>utoo-lint</span><i aria-hidden="true"></i><strong>8.35 ms</strong>
      </div>
      <div class="utlint-benchmark-row utlint-benchmark-row--oxlint">
        <span>Oxlint</span><i aria-hidden="true"></i><strong>57.35 ms</strong>
      </div>
      <div class="utlint-benchmark-row utlint-benchmark-row--biome">
        <span>Biome</span><i aria-hidden="true"></i><strong>61.56 ms</strong>
      </div>
      <div class="utlint-benchmark-row utlint-benchmark-row--eslint">
        <span>ESLint</span><i aria-hidden="true"></i><strong>747.84 ms</strong>
      </div>
    </div>
    <figcaption id="utlint-benchmark-caption">
      100 个 TypeScript 文件 · 12 条共有规则 · 全新进程 · 多次运行的中位数
    </figcaption>
  </figure>
</section>

<section class="utlint-home-section utlint-home-section--migration" aria-labelledby="utlint-migration-title">
  <header class="utlint-home-section-heading">
    <span class="utlint-home-kicker">02 · 渐进迁移</span>
    <h2 id="utlint-migration-title">不用一次性重写，也能迁移 ESLint。</h2>
    <p>
      迁移过程是渐进的。先生成报告，把 utoo-lint 已经原生实现的规则迁移过来；
      暂未覆盖的处理器和自定义插件行为仍由 ESLint 负责。
    </p>
  </header>
  <div class="utlint-migration-boundary">
    <article>
      <h3>现在迁移</h3>
      <p>兼容的规则 ID、严重级别、文件模式，以及可序列化的 flat config 配置项。</p>
      <code>utoo-lint migrate eslint --print</code>
    </article>
    <article>
      <h3>暂留 ESLint</h3>
      <p>尚未覆盖的处理器、项目专用插件，以及依赖类型服务的工作流。</p>
      <a href="/zh-CN/rule-status">查看规则覆盖情况 <span aria-hidden="true">→</span></a>
    </article>
    <article>
      <h3>在 CI 中验证</h3>
      <p>同时运行两个工具、比较 JSON 诊断结果，再逐条移除 ESLint 的重复覆盖。</p>
      <a href="/zh-CN/eslint-migration">打开迁移指南 <span aria-hidden="true">→</span></a>
    </article>
  </div>
</section>

<section class="utlint-home-section utlint-home-section--architecture" aria-labelledby="utlint-architecture-title">
  <header class="utlint-home-section-heading">
    <span class="utlint-home-kicker">03 · 运行方式</span>
    <h2 id="utlint-architecture-title">同一个内核，运行在原生、Node 和 WebAssembly。</h2>
    <p>
      Node 包装层负责加载可信的 TypeScript 配置和发现项目文件；Zig 引擎接收
      可序列化的规则映射；独立的 WebAssembly 构建则检查已经位于内存中的源码。
    </p>
  </header>
  <ol class="utlint-engine-pipeline" aria-label="utoo-lint 配置处理流程">
    <li><strong>utlint.config.ts</strong><span>带类型的配置编写体验</span></li>
    <li><strong>Node 包装层</strong><span>解析文件与配置</span></li>
    <li><strong>Zig 引擎</strong><span>解析、分析和修复</span></li>
    <li><strong>CLI 或 WebAssembly</strong><span>仓库与浏览器环境</span></li>
  </ol>
  <div class="utlint-surface-grid">
    <article>
      <h3>原生 CLI</h3>
      <p>遍历代码仓库、应用项目配置，并写入受支持的修复。</p>
    </article>
    <article>
      <h3>带类型的配置</h3>
      <p>导入预设，并在可信的 Node 入口中保留编辑器自动补全。</p>
    </article>
    <article>
      <h3>浏览器 WebAssembly</h3>
      <p>复用同一个内存中的 Linter，无需把源码发送给远程服务。</p>
    </article>
  </div>
</section>

<aside class="utlint-home-cta" aria-labelledby="utlint-cta-title">
  <div>
    <span class="utlint-home-kicker">本地试用</span>
    <h2 id="utlint-cta-title">用你自己的代码试一次。</h2>
    <p>
      Playground 会直接在浏览器中使用 WebAssembly 构建；你的代码不会上传到
      远程 Lint 服务。
    </p>
  </div>
  <nav class="utlint-home-cta-actions" aria-label="开始使用">
    <a href="/playground/" class="utlint-home-button utlint-home-button--primary">打开 Playground</a>
    <a href="/zh-CN/configuration" class="utlint-home-button utlint-home-button--secondary">阅读文档</a>
  </nav>
</aside>
