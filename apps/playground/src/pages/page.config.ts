import { definePageConfig } from '@evjs/ev';

export default definePageConfig({
  title: 'utoo-lint Playground',
  meta: {
    description: 'Run utoo-lint in the browser and inspect diagnostics or AST output.',
    viewport: 'width=device-width, initial-scale=1',
    'theme-color': '#111315',
  },
  render: 'csr',
});
