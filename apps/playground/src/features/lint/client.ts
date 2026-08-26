import type { LintOptions, LintResult } from '@utoo/lint-wasm';
import type {
  LintWorkerAction,
  LintWorkerError,
  LintWorkerRequest,
  LintWorkerResponse,
} from './protocol';

interface PendingRequest {
  resolve: (result: LintResult) => void;
  reject: (error: LintClientError) => void;
}

export class LintClientError extends Error {
  readonly code?: string;
  readonly ruleId?: string;

  constructor(error: LintWorkerError) {
    super(error.message);
    this.name = error.name;
    this.code = error.code;
    this.ruleId = error.ruleId;
  }
}

export class LintWorkerClient {
  #nextId = 1;
  #worker: Worker | undefined;
  #pending = new Map<number, PendingRequest>();

  run(
    action: LintWorkerAction,
    source: string,
    options: LintOptions,
  ): Promise<LintResult> {
    const worker = this.#getWorker();
    const id = this.#nextId++;
    const request = { id, action, source, options } satisfies LintWorkerRequest;

    return new Promise((resolve, reject) => {
      this.#pending.set(id, { resolve, reject });
      try {
        worker.postMessage(request);
      } catch (error) {
        this.#pending.delete(id);
        worker.terminate();
        if (this.#worker === worker) this.#worker = undefined;
        reject(
          new LintClientError({
            name: error instanceof Error ? error.name : 'WorkerError',
            message:
              error instanceof Error
                ? error.message
                : 'Unable to send work to the lint worker',
          }),
        );
      }
    });
  }

  dispose(): void {
    this.#worker?.terminate();
    this.#worker = undefined;
    this.#rejectAll({
      name: 'AbortError',
      message: 'The lint worker was disposed',
    });
  }

  #getWorker(): Worker {
    if (this.#worker) return this.#worker;

    const worker = new Worker(new URL('./lint.worker.ts', import.meta.url), {
      name: 'utoo-lint',
      type: 'module',
    });

    worker.onmessage = ({ data }: MessageEvent<LintWorkerResponse>) => {
      const pending = this.#pending.get(data.id);
      if (!pending) return;

      this.#pending.delete(data.id);
      if ('error' in data) {
        pending.reject(new LintClientError(data.error));
      } else {
        pending.resolve(data.result);
      }
    };

    worker.onerror = ({ message }) => {
      worker.terminate();
      if (this.#worker === worker) this.#worker = undefined;
      this.#rejectAll({
        name: 'WorkerError',
        message: message || 'The lint worker failed to load',
      });
    };

    worker.onmessageerror = () => {
      worker.terminate();
      if (this.#worker === worker) this.#worker = undefined;
      this.#rejectAll({
        name: 'DataCloneError',
        message: 'The lint worker returned an unreadable response',
      });
    };

    this.#worker = worker;
    return worker;
  }

  #rejectAll(error: LintWorkerError): void {
    for (const pending of this.#pending.values()) {
      pending.reject(new LintClientError(error));
    }
    this.#pending.clear();
  }
}
