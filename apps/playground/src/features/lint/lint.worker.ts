/// <reference lib="webworker" />

import { createUtooLint } from '@utoo/lint-wasm';
import {
  normalizeWorkerError,
  type LintWorkerRequest,
  type LintWorkerResponse,
} from './protocol';

const workerScope = self as unknown as DedicatedWorkerGlobalScope;
const linterPromises = new Map<string, ReturnType<typeof createUtooLint>>();

function getLinter(wasmUrl?: string) {
  const key = wasmUrl ?? 'bundled';
  const existing = linterPromises.get(key);
  if (existing) return existing;

  const candidate = createUtooLint(wasmUrl ? { wasm: wasmUrl } : undefined);
  linterPromises.set(key, candidate);
  void candidate.catch(() => {
    if (linterPromises.get(key) === candidate) linterPromises.delete(key);
  });
  return candidate;
}

workerScope.onmessage = async ({ data }: MessageEvent<LintWorkerRequest>) => {
  const { id, action, source, options, wasmUrl } = data;

  try {
    const linter = await getLinter(wasmUrl);
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
