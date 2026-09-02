import assert from 'node:assert/strict';
import test from 'node:test';

import { publishPackages } from './publish-npm-packages.mjs';

const packages = [
  {
    directory: 'npm/utoo-lint',
    name: '@utoo/lint',
    version: '0.3.4',
  },
  {
    directory: 'npm/@utoo/lint-linux-x64',
    name: '@utoo/lint-linux-x64',
    version: '0.3.4',
  },
  {
    directory: 'npm/@utoo/lint-wasm',
    name: '@utoo/lint-wasm',
    version: '0.3.4',
  },
];

function result(code, { stdout = '', stderr = '' } = {}) {
  return { code, stderr, stdout };
}

function npmRegistryStub({ exactVersions = [], missingPackages = [] } = {}) {
  const exactVersionSet = new Set(exactVersions);
  const missingPackageSet = new Set(missingPackages);
  const calls = [];

  return {
    calls,
    run(command, args, options = {}) {
      calls.push({ args, command, options });

      if (command !== 'npm' || args[0] !== 'view') {
        return result(0);
      }

      const specifier = args[1];
      if (args[2] === 'version' && exactVersionSet.has(specifier)) {
        return result(0, { stdout: '"0.3.4"\n' });
      }

      if (args[2] === 'name' && !missingPackageSet.has(specifier)) {
        return result(0, { stdout: `${JSON.stringify(specifier)}\n` });
      }

      return result(1, {
        stderr: `npm error code E404\nnpm error 404 ${specifier} is not in this registry\n`,
      });
    },
  };
}

function publishCalls(calls) {
  return calls.filter(({ args }) => args[0] === 'publish');
}

test('fails before publishing when a package is not initialized for OIDC', () => {
  const registry = npmRegistryStub({
    missingPackages: ['@utoo/lint-wasm'],
  });

  assert.throws(
    () =>
      publishPackages({
        env: { CI: 'true' },
        logger: { log() {} },
        npmTag: 'latest',
        packages,
        run: registry.run,
      }),
    /initialize.*Trusted Publishing/i,
  );
  assert.deepEqual(publishCalls(registry.calls), []);
});

test('publishes an initialized wasm package through OIDC before native packages', () => {
  const registry = npmRegistryStub();

  publishPackages({
    env: { CI: 'true', NODE_AUTH_TOKEN: 'oidc-placeholder' },
    logger: { log() {} },
    npmTag: 'latest',
    packages,
    run: registry.run,
  });

  const publishes = publishCalls(registry.calls);
  assert.deepEqual(
    publishes.map(({ args, command }) => [command, args[1]]),
    [
      ['pnpm', 'npm/@utoo/lint-wasm/'],
      ['pnpm', 'npm/@utoo/lint-linux-x64/'],
      ['pnpm', 'npm/utoo-lint/'],
    ],
  );
  assert.ok(
    publishes.every(
      ({ options }) =>
        options.env.NODE_AUTH_TOKEN === 'oidc-placeholder',
    ),
  );
});

test('skips exact versions that are already published', () => {
  const registry = npmRegistryStub({
    exactVersions: packages.map(({ name, version }) => `${name}@${version}`),
  });

  publishPackages({
    env: { CI: 'true' },
    logger: { log() {} },
    npmTag: 'latest',
    packages,
    run: registry.run,
  });

  assert.deepEqual(publishCalls(registry.calls), []);
});
