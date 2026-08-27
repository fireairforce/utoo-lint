import type { LintOptions, LintResult } from '@utoo/lint-wasm';

export type LintWorkerAction = 'lint' | 'fix';

export interface LintWorkerRequest {
  id: number;
  action: LintWorkerAction;
  source: string;
  options: LintOptions;
  wasmUrl?: string;
}

export interface LintWorkerError {
  name: string;
  message: string;
  code?: string;
  ruleId?: string;
}

export type LintWorkerResponse =
  | { id: number; result: LintResult }
  | { id: number; error: LintWorkerError };

export function normalizeWorkerError(error: unknown): LintWorkerError {
  if (error instanceof Error) {
    const candidate = error as Error & { code?: unknown; ruleId?: unknown };
    return {
      name: error.name,
      message: error.message,
      ...(typeof candidate.code === 'string' ? { code: candidate.code } : {}),
      ...(typeof candidate.ruleId === 'string' ? { ruleId: candidate.ruleId } : {}),
    };
  }

  return {
    name: 'Error',
    message: typeof error === 'string' ? error : 'Unknown WebAssembly error',
  };
}
