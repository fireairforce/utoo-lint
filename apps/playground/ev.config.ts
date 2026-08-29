import { defineConfig } from '@evjs/ev';
import { staticDeploymentAdapter } from '@evjs/ev/deployment';

export default defineConfig({
  application: {
    routes: [{ path: '/playground', page: '.' }],
  },
  plugins: [staticDeploymentAdapter()],
});
