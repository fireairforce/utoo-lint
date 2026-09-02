import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const workspaceRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

function runCommand(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    encoding: options.stdio === 'pipe' ? 'utf8' : undefined,
    env: options.env,
    stdio: options.stdio ?? 'inherit',
  });

  return {
    code: result.status ?? 1,
    error: result.error,
    stderr: result.stderr ?? '',
    stdout: result.stdout ?? '',
  };
}

function isNotFound(result) {
  const output = `${result.stdout}\n${result.stderr}`;
  return /\bE404\b|404 Not Found|is not in this registry/i.test(output);
}

function describeFailure(command, args, result) {
  const details = [result.stderr, result.stdout, result.error?.message]
    .filter(Boolean)
    .join('\n')
    .trim();
  const suffix = details ? `\n${details}` : '';
  return `${command} ${args.join(' ')} failed with exit code ${result.code}${suffix}`;
}

function runChecked(run, command, args, options) {
  const result = run(command, args, options);
  if (result.code !== 0) {
    throw new Error(describeFailure(command, args, result));
  }
  return result;
}

function readPackage(directory, root) {
  const manifestPath = path.resolve(root, directory, 'package.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (!manifest.name || !manifest.version) {
    throw new Error(`Package manifest is missing name or version: ${manifestPath}`);
  }

  return {
    directory,
    name: manifest.name,
    version: manifest.version,
  };
}

export function discoverPackages(root = workspaceRoot) {
  const scopedRoot = path.resolve(root, 'npm', '@utoo');
  const scopedDirectories = readdirSync(scopedRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && entry.name.startsWith('lint-'))
    .map((entry) => path.posix.join('npm', '@utoo', entry.name));

  return [...scopedDirectories, path.posix.join('npm', 'utoo-lint')].map(
    (directory) => readPackage(directory, root),
  );
}

function publishPriority(pkg) {
  if (pkg.name === '@utoo/lint-wasm') return 0;
  if (pkg.name === '@utoo/lint') return 2;
  return 1;
}

function orderedPackages(packages) {
  return [...packages].sort(
    (left, right) =>
      publishPriority(left) - publishPriority(right) ||
      left.name.localeCompare(right.name),
  );
}

function inspectPackage(pkg, { cwd, env, run }) {
  const exactSpecifier = `${pkg.name}@${pkg.version}`;
  const exactArgs = ['view', exactSpecifier, 'version', '--json'];
  const exactResult = run('npm', exactArgs, { cwd, env, stdio: 'pipe' });
  if (exactResult.code === 0) {
    return { pkg, state: 'published' };
  }
  if (!isNotFound(exactResult)) {
    throw new Error(describeFailure('npm', exactArgs, exactResult));
  }

  const packageArgs = ['view', pkg.name, 'name', '--json'];
  const packageResult = run('npm', packageArgs, {
    cwd,
    env,
    stdio: 'pipe',
  });
  if (packageResult.code === 0) {
    return { pkg, state: 'unpublished-version' };
  }
  if (isNotFound(packageResult)) {
    return { pkg, state: 'missing-package' };
  }

  throw new Error(describeFailure('npm', packageArgs, packageResult));
}

export function publishPackages({
  cwd = workspaceRoot,
  env = process.env,
  logger = console,
  npmTag,
  packages = discoverPackages(cwd),
  run = runCommand,
}) {
  if (!npmTag) {
    throw new Error('NPM_TAG is required');
  }

  const inspections = packages.map((pkg) =>
    inspectPackage(pkg, { cwd, env, run }),
  );
  const missingPackages = inspections
    .filter(({ state }) => state === 'missing-package')
    .map(({ pkg }) => pkg);

  if (missingPackages.length > 0) {
    const names = missingPackages.map(({ name }) => name).join(', ');
    throw new Error(
      `Initialize these npm packages and configure Trusted Publishing for utooland/utoo-lint and release.yml before releasing: ${names}`,
    );
  }

  const inspectionByName = new Map(
    inspections.map(({ pkg, state }) => [pkg.name, state]),
  );

  for (const pkg of orderedPackages(packages)) {
    if (inspectionByName.get(pkg.name) === 'published') {
      logger.log(`Skipping ${pkg.name}@${pkg.version}; already published`);
      continue;
    }

    logger.log(`Publishing ${pkg.name}@${pkg.version} through npm OIDC`);
    runChecked(
      run,
      'pnpm',
      [
        'publish',
        `${pkg.directory}/`,
        '--access',
        'public',
        '--provenance',
        '--tag',
        npmTag,
        '--no-git-checks',
      ],
      { cwd, env, stdio: 'inherit' },
    );
  }
}

const invokedPath = process.argv[1]
  ? pathToFileURL(path.resolve(process.argv[1])).href
  : '';
if (import.meta.url === invokedPath) {
  publishPackages({
    npmTag: process.env.NPM_TAG,
  });
}
