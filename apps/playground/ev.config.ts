import { defineConfig } from '@evjs/ev';
import { staticDeploymentAdapter } from '@evjs/ev/deployment';
import { definePlugin } from '@evjs/ev/plugin';

interface CopyCapableBundlerConfig {
  output?: {
    copy?: Array<string | { from: string; to?: string }>;
  };
}

const versionAssetsPlugin = definePlugin({
  id: 'playground-version-assets',
  setup() {
    return {
      configureBundler(config, context) {
        if (context.bundlerName !== 'utoopack') return;

        const utoopackConfig = config as CopyCapableBundlerConfig;
        utoopackConfig.output ??= {};
        utoopackConfig.output.copy = [
          ...(utoopackConfig.output.copy ?? []),
          { from: 'public/versions', to: 'versions' },
          ...(context.mode === 'development'
            ? [{ from: 'public/versions', to: 'playground/versions' }]
            : []),
        ];
      },
    };
  },
});

export default defineConfig({
  application: {
    routes: [{ path: '/playground', page: '.' }],
  },
  plugins: [versionAssetsPlugin(), staticDeploymentAdapter()],
});
