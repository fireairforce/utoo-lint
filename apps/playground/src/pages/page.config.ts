import { definePageConfig } from '@evjs/ev';

export default definePageConfig({
  title: 'utoo-lint Playground',
  meta: {
    description: 'Run utoo-lint in your browser with WebAssembly.',
    viewport: 'width=device-width, initial-scale=1',
    'theme-color': '#0d1117',
  },
  render: 'csr',
});
