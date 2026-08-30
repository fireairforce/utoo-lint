import { defineConfig } from 'dumi';

export default defineConfig({
  outputPath: 'dist/site',
  base: '/',
  publicPath: '/',
  hash: true,
  exportStatic: {},
  ssr: {},
  sitemap: {
    hostname: 'https://utlint.umijs.org',
  },
  locales: [
    { id: 'en-US', name: 'English', base: '/' },
    { id: 'zh-CN', name: '中文', base: '/zh-CN' },
  ],
  resolve: {
    docDirs: ['docs'],
    atomDirs: [],
  },
  metas: [
    { name: 'theme-color', content: '#f5f4ef' },
    {
      name: 'keywords',
      content: 'linter, JavaScript, TypeScript, Zig, ESLint, WebAssembly',
    },
    { property: 'og:type', content: 'website' },
    { property: 'og:site_name', content: 'utoo-lint' },
    {
      property: 'og:image',
      content: 'https://utlint.umijs.org/utoo-lint-og.png',
    },
    { name: 'twitter:card', content: 'summary_large_image' },
  ],
  links: [{ rel: 'icon', href: '/utoo-lint-mark.svg', type: 'image/svg+xml' }],
  theme: {
    '@c-primary': '#086ca8',
    '@c-primary-dark': '#55b9ed',
  },
  themeConfig: {
    name: 'utoo-lint',
    logo: '/utoo-lint-mark.svg',
    nav: {
      mode: 'override',
      value: {
        'en-US': [
          { title: 'Configuration', link: '/configuration' },
          { title: 'Rules', link: '/rule-status' },
          { title: 'Migration', link: '/eslint-migration' },
        ],
        'zh-CN': [
          { title: '配置', link: '/zh-CN/configuration' },
          { title: '规则', link: '/zh-CN/rule-status' },
          { title: '迁移', link: '/zh-CN/eslint-migration' },
        ],
      },
    },
    socialLinks: {
      github: 'https://github.com/utooland/utoo-lint',
    },
    prefersColor: {
      default: 'light',
      switch: true,
    },
    footer:
      'Released under the MIT License · Built by the utoo-lint contributors',
  },
});
