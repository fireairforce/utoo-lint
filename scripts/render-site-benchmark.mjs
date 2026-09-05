import { readFile, writeFile } from 'node:fs/promises';

const directory = new URL('../public/benchmarks/', import.meta.url);
const data = JSON.parse(
  await readFile(new URL('2026-08-30.json', directory), 'utf8'),
);
const labels = {
  'utoo-lint': 'utoo-lint',
  oxlint: 'Oxlint',
  biome: 'Biome',
  eslint: 'ESLint',
};
const rows = data.results.map(({ name, summary }) => ({
  name: labels[name],
  ms: summary.medianMs,
}));
if (
  rows.length !== 4 ||
  rows.some(
    ({ name, ms }) => !name || !Number.isFinite(ms) || ms <= 0 || ms > 800,
  )
)
  throw new Error('Unexpected benchmark snapshot');
const escape = (text) =>
  String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
for (const language of ['en', 'zh']) {
  const title = language === 'en' ? 'Median CLI time' : 'CLI 耗时中位数';
  const subtitle =
    language === 'en'
      ? 'Linear scale · milliseconds · lower is better'
      : '线性刻度 · 毫秒 · 越低越好';
  const axis = [0, 200, 400, 600, 800]
    .map((value) => {
      const x = 166 + (value / 800) * 674;
      return `<path d="M${x} 110V424" stroke="#2a3646"/><text x="${x}" y="463" text-anchor="middle" class="axis">${value}</text>`;
    })
    .join('');
  const bars = rows
    .map(({ name, ms }, i) => {
      const y = 135 + i * 78;
      const primary = name === 'utoo-lint';
      return `<text x="30" y="${y + 28}" class="label" fill="${primary ? '#8bd0ff' : '#d9e3f1'}">${escape(name)}</text><rect x="166" y="${y}" width="${((ms / 800) * 674).toFixed(3)}" height="40" rx="3" fill="${primary ? '#67bfff' : '#637997'}"/><text x="958" y="${y + 28}" text-anchor="end" class="value" fill="${primary ? '#8bd0ff' : '#f1f5fc'}">${ms.toFixed(2)} ms</text>`;
    })
    .join('');
  const description = rows
    .map((row) => `${row.name}: ${row.ms.toFixed(2)} ms`)
    .join('; ');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="510" viewBox="0 0 1000 510" role="img" aria-labelledby="title desc"><title id="title">${title}</title><desc id="desc">${escape(description)}. ${subtitle}.</desc><style>text{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Noto Sans CJK SC',sans-serif}.title{font-size:24px;font-weight:600;fill:#f1f5fc}.subtitle,.axis{font-size:17px;fill:#a5b3c8}.label,.value{font-size:21px;font-weight:500}.value{font-variant-numeric:tabular-nums}</style><rect width="1000" height="510" fill="#151c26"/><text x="30" y="43" class="title">${title}</text><text x="30" y="76" class="subtitle">${subtitle}</text>${axis}${bars}<text x="840" y="490" text-anchor="end" class="axis">ms</text></svg>\n`;
  await writeFile(new URL(`comparison-${language}.svg`, directory), svg);
  const compactBars = rows
    .map(({ name, ms }, i) => {
      const y = 125 + i * 92;
      const primary = name === 'utoo-lint';
      return `<text x="24" y="${y}" font-size="24" fill="${primary ? '#8bd0ff' : '#d9e3f1'}">${name}</text><text x="476" y="${y}" font-size="24" text-anchor="end" fill="#f1f5fc">${ms.toFixed(2)} ms</text><rect x="24" y="${y + 16}" width="452" height="28" rx="3" fill="#253344"/><rect x="24" y="${y + 16}" width="${((ms / 800) * 452).toFixed(3)}" height="28" rx="3" fill="${primary ? '#67bfff' : '#637997'}"/>`;
    })
    .join('');
  const compact = `<svg xmlns="http://www.w3.org/2000/svg" width="500" height="580" viewBox="0 0 500 580" role="img" aria-labelledby="title desc"><title id="title">${title}</title><desc id="desc">${escape(description)}. ${subtitle}.</desc><style>text{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Noto Sans CJK SC',sans-serif}</style><rect width="500" height="580" fill="#151c26"/><text x="24" y="42" font-size="26" font-weight="600" fill="#f1f5fc">${title}</text><text x="24" y="76" font-size="19" fill="#a5b3c8">${language === 'en' ? 'Linear scale · lower is better' : '线性刻度 · 越低越好'}</text>${compactBars}<path d="M24 492H476" stroke="#637997"/>${[0, 200, 400, 600, 800].map((value) => `<text x="${24 + (value / 800) * 452}" y="526" text-anchor="${value === 0 ? 'start' : value === 800 ? 'end' : 'middle'}" font-size="19" fill="#a5b3c8">${value}</text>`).join('')}<text x="476" y="555" text-anchor="end" font-size="19" fill="#a5b3c8">ms</text></svg>\n`;
  await writeFile(
    new URL(`comparison-${language}-compact.svg`, directory),
    compact,
  );
}
console.log(
  'Rendered English and Chinese benchmark images from the archived measurements.',
);
