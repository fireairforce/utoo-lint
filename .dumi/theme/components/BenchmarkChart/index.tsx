import React, { useEffect, useRef, useState } from 'react';
import benchmark from '../../../../public/benchmarks/2026-08-30.json';

const tools = benchmark.results.map((result, index) => ({
  ...result,
  label: ['utoo-lint', 'Oxlint', 'Biome', 'ESLint'][index],
  color: ['#67d4ff', '#a6c7ef', '#89dbc1', '#b5a0ef'][index],
}));

const messages = {
  en: {
    title: 'Every millisecond counts.',
    workload: `${benchmark.targetFiles} TypeScript files · ${benchmark.rules.length} shared rules`,
    all: 'All tools',
    native: 'Native tools',
    scope: 'Tools to compare',
    replay: 'Replay',
    median: 'Median CLI time',
    direction: 'Shorter is faster',
    fastest: 'Fastest',
    select: 'Select a tool to explore its runs',
    range: 'Observed range',
    runs: 'measured runs',
    axis: 'Linear scale from zero',
    note: 'Recorded Aug 30, 2026 · macOS arm64 · Node.js 20.19.1 · 5 warmups per tool.',
    image: 'Save chart',
  },
  zh: {
    title: '每一毫秒，都算数。',
    workload: `${benchmark.targetFiles} 个 TypeScript 文件 · ${benchmark.rules.length} 条共有规则`,
    all: '全部工具',
    native: '原生工具',
    scope: '选择对比工具',
    replay: '重播',
    median: 'CLI 耗时中位数',
    direction: '越短越快',
    fastest: '最快',
    select: '点击工具，查看每次测量',
    range: '实测耗时范围',
    runs: '次测量',
    axis: '从零起算的线性刻度',
    note: '记录于 2026-08-30 · macOS arm64 · Node.js 20.19.1 · 每个工具预热 5 次。',
    image: '保存图表',
  },
};

export default function BenchmarkChart({ chinese }: { chinese: boolean }) {
  const t = messages[chinese ? 'zh' : 'en'];
  const chart = useRef<HTMLElement>(null);
  const [nativeOnly, setNativeOnly] = useState(false);
  const [selected, setSelected] = useState(tools[0].name);
  const [animated, setAnimated] = useState(false);
  const [replay, setReplay] = useState(0);
  const visibleTools = tools.filter(
    (tool) => !nativeOnly || tool.name !== 'eslint',
  );
  const activeTool =
    visibleTools.find((tool) => tool.name === selected) ?? tools[0];
  const domain = nativeOnly ? 50 : 800;
  const { minMs, maxMs } = activeTool.summary;
  const points = activeTool.samplesMs
    .map(
      (sample, index, samples) =>
        `${4 + (index / (samples.length - 1)) * 192},${40 - ((sample - minMs) / (maxMs - minMs || 1)) * 32}`,
    )
    .join(' ');

  useEffect(() => {
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    // The server-rendered chart is complete and readable, including without JS.
    // Animate once when it enters view; never loop while the visitor is reading.
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setAnimated(!motion.matches);
          observer.disconnect();
        }
      },
      { threshold: 0.25 },
    );
    if (chart.current) observer.observe(chart.current);
    const stopMotion = () => {
      if (motion.matches) setAnimated(false);
    };
    motion.addEventListener('change', stopMotion);
    return () => {
      observer.disconnect();
      motion.removeEventListener('change', stopMotion);
    };
  }, []);

  function selectScope(native: boolean) {
    setNativeOnly(native);
    if (native && selected === 'eslint') setSelected(tools[0].name);
  }

  return (
    <figure
      ref={chart}
      className="product-chart"
      aria-labelledby="benchmark-chart-title"
      data-animated={animated}
      data-domain={domain}
    >
      <div className="benchmark-chart-header">
        <div>
          <span className="benchmark-workload">{t.workload}</span>
          <h3 id="benchmark-chart-title">{t.title}</h3>
        </div>
        <span className="benchmark-direction">
          <span aria-hidden="true">↘</span> {t.direction}
        </span>
      </div>
      <div className="benchmark-toolbar">
        <div className="benchmark-scope" role="group" aria-label={t.scope}>
          <button
            type="button"
            aria-pressed={!nativeOnly}
            onClick={() => selectScope(false)}
          >
            {t.all}
          </button>
          <button
            type="button"
            aria-pressed={nativeOnly}
            onClick={() => selectScope(true)}
          >
            {t.native}
          </button>
        </div>
        <button
          type="button"
          className="benchmark-replay"
          onClick={() => {
            setAnimated(
              !window.matchMedia('(prefers-reduced-motion: reduce)').matches,
            );
            setReplay((value) => value + 1);
          }}
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 20 20"
            fill="none"
            aria-hidden="true"
          >
            <path
              d="M3.5 8a6.5 6.5 0 1 1 .8 6M3.5 3.5V8H8"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          {t.replay}
        </button>
      </div>
      <div
        className="benchmark-plot"
        role="group"
        aria-label={`${t.median} · ${t.axis}`}
      >
        <div className="benchmark-plot-label">
          <span>{t.median}</span>
          <span>ms</span>
        </div>
        <div
          className="benchmark-lanes"
          style={{ '--lane-count': visibleTools.length } as React.CSSProperties}
        >
          <div className="benchmark-grid" aria-hidden="true">
            {[0, 1, 2, 3, 4].map((tick) => (
              <i key={tick} style={{ left: `${tick * 25}%` }} />
            ))}
          </div>
          {visibleTools.map((tool, index) => (
            <button
              type="button"
              key={tool.name}
              className="benchmark-lane"
              aria-pressed={activeTool.name === tool.name}
              aria-label={`${tool.label}: ${tool.summary.medianMs.toFixed(2)} ${chinese ? '毫秒' : 'milliseconds'}`}
              onClick={() => setSelected(tool.name)}
              style={
                {
                  '--tool-color': tool.color,
                  '--bar-delay': `${index * 75}ms`,
                } as React.CSSProperties
              }
            >
              <span className="benchmark-tool">
                <i aria-hidden="true" />
                {tool.label}
              </span>
              <span className="benchmark-track" aria-hidden="true">
                <span
                  className="benchmark-bar"
                  style={{
                    width: `${(tool.summary.medianMs / domain) * 100}%`,
                  }}
                >
                  <span
                    key={`${nativeOnly}-${replay}`}
                    className="benchmark-bar-fill"
                  />
                </span>
              </span>
              <span className="benchmark-value" aria-hidden="true">
                {tool.summary.medianMs.toFixed(2)}
                <small>ms</small>
              </span>
            </button>
          ))}
        </div>
        <div className="benchmark-axis" aria-hidden="true">
          {[0, 1, 2, 3, 4].map((tick) => (
            <span key={tick}>{(tick * domain) / 4}</span>
          ))}
        </div>
        <div className="benchmark-plot-hint">
          <span>{t.select}</span>
          <span>{t.axis}</span>
        </div>
      </div>
      <div
        className="benchmark-detail"
        style={{ '--tool-color': activeTool.color } as React.CSSProperties}
      >
        <div
          className="benchmark-detail-title"
          aria-live="polite"
          aria-atomic="true"
        >
          <strong>
            {activeTool.label}
            {activeTool.name === tools[0].name && <span>{t.fastest}</span>}
          </strong>
          <span>
            {activeTool.runs} {t.runs}
          </span>
        </div>
        <svg
          key={activeTool.name}
          className="benchmark-sparkline"
          viewBox="0 0 200 48"
          role="img"
          aria-label={`${activeTool.label} · ${minMs.toFixed(2)}–${maxMs.toFixed(2)} ms`}
        >
          <path d="M4 44H196" stroke="currentColor" opacity="0.15" />
          <polyline
            points={points}
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinejoin="round"
            strokeLinecap="round"
            pathLength="1"
          />
          {activeTool.samplesMs.map((sample, index) => (
            <circle
              key={index}
              cx={4 + (index / (activeTool.samplesMs.length - 1)) * 192}
              cy={40 - ((sample - minMs) / (maxMs - minMs || 1)) * 32}
              r="2"
              fill="currentColor"
            >
              <title>
                {chinese ? `第 ${index + 1} 次` : `Run ${index + 1}`}:{' '}
                {sample.toFixed(3)} ms
              </title>
            </circle>
          ))}
        </svg>
        <div className="benchmark-range" aria-live="polite" aria-atomic="true">
          <span>{t.range}</span>
          <strong>
            {minMs.toFixed(2)}–{maxMs.toFixed(2)}
            <small>ms</small>
          </strong>
        </div>
      </div>
      <figcaption>
        <span>{t.note}</span>
        <a
          href={`/benchmarks/comparison-${chinese ? 'zh' : 'en'}.svg`}
          download
        >
          {t.image} <span aria-hidden="true">↓</span>
        </a>
      </figcaption>
    </figure>
  );
}
