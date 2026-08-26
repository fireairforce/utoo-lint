import { defineConfig } from '@evjs/ev';
import { staticDeploymentAdapter } from '@evjs/ev/deployment';

export default defineConfig({
  routing: { mode: 'spa' },
  plugins: [staticDeploymentAdapter()],
});
