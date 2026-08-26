/// <reference lib="webworker" />

import { createUtooLint } from '@utoo/lint-wasm';
import {
  normalizeWorkerError,
  type LintWorkerRequest,
  type LintWorkerResponse,
} from './protocol';

const workerScope = self as unknown as DedicatedWorkerGlobalScope;
let linterPromise: ReturnType<typeof createUtooLint> | undefined;

function getLinter() {
  if (!linterPromise) {
    const candidate = createUtooLint();
    linterPromise = candidate;
    void candidate.catch(() => {
      if (linterPromise === candidate) linterPromise = undefined;
    });
  }

  return linterPromise;
}

workerScope.onmessage = async ({ data }: MessageEvent<LintWorkerRequest>) => {
  const { id, action, source, options } = data;

  try {
    const linter = await getLinter();
    const result =
      action === 'fix'
        ? linter.lintAndFix(source, options)
        : linter.lint(source, options);

    workerScope.postMessage({ id, result } satisfies LintWorkerResponse);
  } catch (error) {
    workerScope.postMessage({
      id,
      error: normalizeWorkerError(error),
    } satisfies LintWorkerResponse);
  }
};
