import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { promisify } from 'node:util';
import test from 'node:test';

const run = promisify(execFile);
const playgroundDirectory = fileURLToPath(new URL('..', import.meta.url));
const outputDirectory = await mkdtemp(join(tmpdir(), 'utoo-lint-client-'));
await run(
  process.execPath,
  [
    fileURLToPath(
      new URL('../node_modules/typescript/bin/tsc', import.meta.url),
    ),
    '--ignoreConfig',
    fileURLToPath(new URL('../src/features/lint/client.ts', import.meta.url)),
    fileURLToPath(new URL('../src/features/ast/client.ts', import.meta.url)),
    fileURLToPath(
      new URL('../src/features/playground/model.ts', import.meta.url),
    ),
    '--target',
    'es2022',
    '--module',
    'es2022',
    '--moduleResolution',
    'bundler',
    '--lib',
    'es2022,dom',
    '--skipLibCheck',
    '--outDir',
    outputDirectory,
  ],
  { cwd: playgroundDirectory },
);
await writeFile(join(outputDirectory, 'package.json'), '{"type":"module"}');
const compiledASTClient = join(outputDirectory, 'ast', 'client.js');
await writeFile(
  compiledASTClient,
  (await readFile(compiledASTClient, 'utf8')).replace(
    "from './protocol';",
    "from './protocol.js';",
  ),
);
const { LintWorkerClient } = await import(
  pathToFileURL(join(outputDirectory, 'lint', 'client.js')).href
);
const { ASTWorkerClient } = await import(
  pathToFileURL(join(outputDirectory, 'ast', 'client.js')).href
);
const { AST_SOURCE_LENGTH_MAX } = await import(
  pathToFileURL(join(outputDirectory, 'ast', 'protocol.js')).href
);
const {
  fileNameForLanguage,
  INITIAL_SOURCES,
  RECOMMENDED_RULES,
} = await import(
  pathToFileURL(join(outputDirectory, 'playground', 'model.js')).href
);
await rm(outputDirectory, { force: true, recursive: true });

class MockWorker {
  static instances = [];

  messages = [];
  onerror = null;
  onmessage = null;
  onmessageerror = null;

  constructor() {
    MockWorker.instances.push(this);
  }

  postMessage(message) {
    this.messages.push(message);
  }

  respond(data) {
    this.onmessage?.({ data });
  }

  terminate() {}
}

test('coalesces queued lint work to the newest request', async (t) => {
  MockWorker.instances = [];
  globalThis.Worker = MockWorker;

  const client = new LintWorkerClient();
  t.after(() => {
    client.dispose();
    delete globalThis.Worker;
  });
  const first = client.run('lint', 'first', {});
  void first.catch(() => {});
  const superseded = client.run('lint', 'superseded', {});
  const supersededAssertion = assert.rejects(
    superseded,
    (error) =>
      error?.name === 'AbortError' && /superseded/i.test(error.message),
  );
  const latest = client.run('lint', 'latest', {});
  void latest.catch(() => {});
  const worker = MockWorker.instances[0];

  assert.deepEqual(
    worker.messages.map(({ source }) => source),
    ['first'],
  );
  await supersededAssertion;

  const firstResult = { diagnostics: [], mode: 'lint' };
  worker.respond({ id: worker.messages[0].id, result: firstResult });
  assert.equal(await first, firstResult);
  assert.deepEqual(
    worker.messages.map(({ source }) => source),
    ['first', 'latest'],
  );

  const latestResult = { diagnostics: [], mode: 'lint' };
  worker.respond({ id: worker.messages[1].id, result: latestResult });
  assert.equal(await latest, latestResult);
});

test('can discard queued work before its debounce replacement is ready', async (t) => {
  MockWorker.instances = [];
  globalThis.Worker = MockWorker;

  const client = new LintWorkerClient();
  t.after(() => {
    client.dispose();
    delete globalThis.Worker;
  });
  const active = client.run('lint', 'active', {});
  void active.catch(() => {});
  const queued = client.run('lint', 'queued', {});
  const queuedAssertion = assert.rejects(
    queued,
    (error) =>
      error?.name === 'AbortError' && /superseded/i.test(error.message),
  );
  const worker = MockWorker.instances[0];

  client.cancelQueued();
  await queuedAssertion;
  worker.respond({
    id: worker.messages[0].id,
    result: { diagnostics: [], mode: 'lint' },
  });
  await active;
  assert.deepEqual(
    worker.messages.map(({ source }) => source),
    ['active'],
  );
});

test('coalesces queued AST work to the newest source', async (t) => {
  MockWorker.instances = [];
  globalThis.Worker = MockWorker;

  const client = new ASTWorkerClient();
  t.after(() => {
    client.dispose();
    delete globalThis.Worker;
  });
  const first = client.parse('first', 'index.ts');
  void first.catch(() => {});
  const superseded = client.parse('superseded', 'index.ts');
  const supersededAssertion = assert.rejects(
    superseded,
    (error) =>
      error?.name === 'AbortError' && /superseded/i.test(error.message),
  );
  const latest = client.parse('latest', 'index.ts');
  void latest.catch(() => {});
  const worker = MockWorker.instances[0];

  assert.deepEqual(
    worker.messages.map(({ source }) => source),
    ['first'],
  );
  await supersededAssertion;

  const firstResult = { diagnostics: [], elapsedMs: 1, program: {} };
  worker.respond({ id: worker.messages[0].id, result: firstResult });
  assert.equal(await first, firstResult);
  assert.deepEqual(
    worker.messages.map(({ source }) => source),
    ['first', 'latest'],
  );

  const latestResult = { diagnostics: [], elapsedMs: 2, program: {} };
  worker.respond({ id: worker.messages[1].id, result: latestResult });
  assert.equal(await latest, latestResult);
});

test('rejects oversized AST input before starting a worker', async () => {
  MockWorker.instances = [];
  globalThis.Worker = MockWorker;

  const client = new ASTWorkerClient();
  await assert.rejects(
    client.parse('x'.repeat(AST_SOURCE_LENGTH_MAX + 1), 'index.ts'),
    (error) => error?.name === 'RangeError' && /exceeds/i.test(error.message),
  );
  assert.equal(MockWorker.instances.length, 0);
  client.dispose();
  delete globalThis.Worker;
});

test('fixes every diagnostic in each default Playground fixture', async () => {
  const { createUtooLint } = await import('@utoo/lint-wasm');
  const { langFromPath, parse } = await import('@yuku-parser/wasm');
  const linter = await createUtooLint();

  for (const [language, source] of Object.entries(INITIAL_SOURCES)) {
    const options = {
      filePath: fileNameForLanguage(language),
      rules: RECOMMENDED_RULES,
    };
    const before = linter.lint(source, options);
    assert.ok(
      before.diagnostics.length > 0,
      `${language} should demonstrate lint errors`,
    );
    assert.ok(
      before.diagnostics.every((diagnostic) => diagnostic.fixes.length > 0),
      `${language} should only demonstrate fixable diagnostics`,
    );

    const fixed = linter.lintAndFix(source, options);
    assert.equal(fixed.fixed, true, `${language} should be changed`);
    assert.deepEqual(
      fixed.diagnostics,
      [],
      `${language} should be clean after one Fix all action`,
    );

    const ast = parse(source, {
      lang: langFromPath(options.filePath),
      preserveParens: true,
      sourceType: 'module',
    });
    assert.equal(ast.program.type, 'Program');
    assert.equal(ast.program.start, 0);
    assert.equal(ast.program.end, source.length);
  }
});
