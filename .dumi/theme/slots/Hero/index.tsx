import { Link, useLocale, useRouteMeta } from 'dumi';
import React, { useState } from 'react';
import SourceCode from '../../builtins/SourceCode';
import NativeLink from '../../components/NativeLink';

const before = `function greet(name: string) {
  let message = \`Hello, \${name}\`;;
  const messages = new Array(message, 'Welcome');
  return { messages: messages };
}

greet('utoo');`;
const after = `function greet(name: string) {
  const message = \`Hello, \${name}\`;
  const messages = [message, 'Welcome'];
  return { messages };
}

greet('utoo');`;

interface HeroData {
  title: string;
  accent: string;
  description: string;
}

export default function Hero() {
  const { frontmatter } = useRouteMeta();
  const isChinese = useLocale().id === 'zh-CN';
  const [fixed, setFixed] = useState(false);
  if (!frontmatter.hero) return null;
  const hero = frontmatter.hero as HeroData;
  const docs = isChinese ? '/zh-CN' : '';

  return (
    <section
      className="dumi-default-hero product-hero"
      aria-labelledby="product-title"
    >
      <div className="product-container product-hero-grid">
        <div className="product-hero-copy">
          <div className="product-eyebrow">
            <span />
            {isChinese
              ? '用 Zig 构建的 JavaScript / TypeScript Linter'
              : 'A JavaScript / TypeScript linter, built in Zig'}
          </div>
          <h1 id="product-title">
            {hero.title} <span>{hero.accent}</span>
          </h1>
          <p>{hero.description}</p>
          <div className="product-actions">
            <Link
              className="product-button product-button-primary"
              to={`${docs}/quick-start`}
            >
              {isChinese ? '快速开始' : 'Quick Start'}
              <span aria-hidden="true">↗</span>
            </Link>
            <NativeLink className="product-button" href="/playground/">
              {isChinese ? '打开 Playground' : 'Open Playground'}
              <span aria-hidden="true">→</span>
            </NativeLink>
          </div>
          <div className="product-install">
            <SourceCode lang="bash">pnpm add -D @utoo/lint</SourceCode>
            <span>
              {isChinese
                ? 'Node.js 20+ · 自带原生二进制，无需安装 Zig'
                : 'Node.js 20+ · Prebuilt binaries. No Zig setup.'}
            </span>
          </div>
        </div>
        <div className="product-demo">
          <div className="product-demo-title">
            <span>
              <span className="product-code-symbol" aria-hidden="true">
                {'</>'}
              </span>{' '}
              index.ts
            </span>
            <span>TypeScript</span>
          </div>
          <div className="product-demo-tools">
            <span>{isChinese ? '自动修复示例' : 'Autofix example'}</span>
            <div
              role="group"
              aria-label={isChinese ? '查看修复示例' : 'View autofix example'}
            >
              <button
                type="button"
                aria-pressed={!fixed}
                onClick={() => setFixed(false)}
              >
                {isChinese ? '修复前' : 'Before'}
              </button>
              <button
                type="button"
                aria-pressed={fixed}
                onClick={() => setFixed(true)}
              >
                {isChinese ? '修复后' : 'After fix'}
              </button>
            </div>
          </div>
          <SourceCode lang="typescript">{fixed ? after : before}</SourceCode>
          <div className="product-demo-result" data-fixed={fixed} role="status">
            <span className="product-demo-status" aria-hidden="true">
              {fixed ? '✓' : '!'}
            </span>
            <div>
              <strong>
                {fixed
                  ? isChinese
                    ? '4 处问题，已全部修复。'
                    : 'Four fixes. Cleaner code.'
                  : isChinese
                    ? '4 处可自动修复的问题'
                    : '4 diagnostics with safe autofixes'}
              </strong>
              <span>
                {fixed
                  ? isChinese
                    ? '常量、数组字面量与属性简写。'
                    : 'Constants, array literals, and property shorthand.'
                  : 'no-extra-semi · prefer-const · object-shorthand · no-array-constructor'}
              </span>
            </div>
          </div>
          <div className="product-demo-footer">
            <code>utoo-lint --fix src</code>
            <span>
              {isChinese ? '只应用受支持的修复' : 'Apply supported fixes'}
            </span>
          </div>
        </div>
      </div>
      <div className="product-container product-compatibility">
        <span>{isChinese ? '融入你的技术栈' : 'Fits your stack'}</span>
        <ul
          aria-label={
            isChinese
              ? '支持的语言与生态'
              : 'Supported languages and ecosystems'
          }
        >
          <li>JavaScript</li>
          <li>TypeScript</li>
          <li>React & JSX</li>
          <li>Node.js</li>
          <li>WebAssembly</li>
        </ul>
        <a
          href="https://github.com/utooland/utoo-lint"
          target="_blank"
          rel="noreferrer"
        >
          GitHub <span aria-hidden="true">↗</span>
        </a>
      </div>
    </section>
  );
}
