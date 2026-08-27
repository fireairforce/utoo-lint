import type { LintOptions, LintResult } from '@utoo/lint-wasm';
import type {
  LintWorkerAction,
  LintWorkerError,
  LintWorkerRequest,
  LintWorkerResponse,
} from './protocol';

interface PendingRequest {
  request: LintWorkerRequest;
  resolve: (result: LintResult) => void;
  reject: (error: LintClientError) => void;
}

const SUPERSEDED_REQUEST: LintWorkerError = {
  name: 'AbortError',
  message: 'The lint request was superseded by a newer request',
};

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
  #active: PendingRequest | undefined;
  #queued: PendingRequest | undefined;

  run(
    action: LintWorkerAction,
    source: string,
    options: LintOptions,
    wasmUrl?: string,
  ): Promise<LintResult> {
    const id = this.#nextId++;
    const request = {
      id,
      action,
      source,
      options,
      ...(wasmUrl ? { wasmUrl } : {}),
    } satisfies LintWorkerRequest;

    return new Promise((resolve, reject) => {
      const pending = { request, resolve, reject } satisfies PendingRequest;

      if (this.#active) {
        this.cancelQueued();
        this.#queued = pending;
        return;
      }

      this.#start(pending);
    });
  }

  cancelQueued(): void {
    const queued = this.#queued;
    if (!queued) return;

    this.#queued = undefined;
    queued.reject(new LintClientError(SUPERSEDED_REQUEST));
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
      const active = this.#active;
      if (!active || active.request.id !== data.id) return;

      this.#active = undefined;
      if ('error' in data) {
        active.reject(new LintClientError(data.error));
      } else {
        active.resolve(data.result);
      }
      this.#startQueued();
    };

    worker.onerror = ({ message }) => {
      if (this.#worker !== worker) return;
      worker.terminate();
      this.#worker = undefined;
      this.#rejectAll({
        name: 'WorkerError',
        message: message || 'The lint worker failed to load',
      });
    };

    worker.onmessageerror = () => {
      if (this.#worker !== worker) return;
      worker.terminate();
      this.#worker = undefined;
      this.#rejectAll({
        name: 'DataCloneError',
        message: 'The lint worker returned an unreadable response',
      });
    };

    this.#worker = worker;
    return worker;
  }

  #start(pending: PendingRequest): void {
    this.#active = pending;

    try {
      this.#getWorker().postMessage(pending.request);
    } catch (error) {
      this.#worker?.terminate();
      this.#worker = undefined;
      this.#rejectAll({
        name: error instanceof Error ? error.name : 'WorkerError',
        message:
          error instanceof Error
            ? error.message
            : 'Unable to send work to the lint worker',
      });
    }
  }

  #startQueued(): void {
    const queued = this.#queued;
    if (this.#active || !queued) return;

    this.#queued = undefined;
    this.#start(queued);
  }

  #rejectAll(error: LintWorkerError): void {
    this.#active?.reject(new LintClientError(error));
    this.#queued?.reject(new LintClientError(error));
    this.#active = undefined;
    this.#queued = undefined;
  }
}
