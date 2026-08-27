import {
  AST_SOURCE_LENGTH_MAX,
  type ASTParseResult,
  type ASTWorkerError,
  type ASTWorkerRequest,
  type ASTWorkerResponse,
} from './protocol';

interface PendingRequest {
  reject: (error: ASTClientError) => void;
  request: ASTWorkerRequest;
  resolve: (result: ASTParseResult) => void;
}

const SUPERSEDED_REQUEST: ASTWorkerError = {
  message: 'The AST request was superseded by newer source',
  name: 'AbortError',
};

export class ASTClientError extends Error {
  constructor(error: ASTWorkerError) {
    super(error.message);
    this.name = error.name;
  }
}

export class ASTWorkerClient {
  #active: PendingRequest | undefined;
  #nextId = 1;
  #queued: PendingRequest | undefined;
  #worker: Worker | undefined;

  parse(source: string, filePath: string): Promise<ASTParseResult> {
    if (source.length > AST_SOURCE_LENGTH_MAX) {
      return Promise.reject(
        new ASTClientError({
          message: `AST input exceeds ${AST_SOURCE_LENGTH_MAX.toLocaleString()} characters`,
          name: 'RangeError',
        }),
      );
    }

    const request = {
      filePath,
      id: this.#nextId++,
      source,
    } satisfies ASTWorkerRequest;

    return new Promise((resolve, reject) => {
      const pending = { reject, request, resolve } satisfies PendingRequest;

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
    queued.reject(new ASTClientError(SUPERSEDED_REQUEST));
  }

  dispose(): void {
    this.#worker?.terminate();
    this.#worker = undefined;
    this.#rejectAll({
      message: 'The AST worker was disposed',
      name: 'AbortError',
    });
  }

  #getWorker(): Worker {
    if (this.#worker) return this.#worker;

    const worker = new Worker(new URL('./ast.worker.ts', import.meta.url), {
      name: 'utoo-lint-ast',
      type: 'module',
    });

    worker.onmessage = ({ data }: MessageEvent<ASTWorkerResponse>) => {
      const active = this.#active;
      if (!active || active.request.id !== data.id) return;

      this.#active = undefined;
      if ('error' in data) {
        active.reject(new ASTClientError(data.error));
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
        message: message || 'The AST worker failed to load',
        name: 'WorkerError',
      });
    };

    worker.onmessageerror = () => {
      if (this.#worker !== worker) return;
      worker.terminate();
      this.#worker = undefined;
      this.#rejectAll({
        message: 'The AST worker returned an unreadable response',
        name: 'DataCloneError',
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
        message:
          error instanceof Error
            ? error.message
            : 'Unable to send source to the AST worker',
        name: error instanceof Error ? error.name : 'WorkerError',
      });
    }
  }

  #startQueued(): void {
    const queued = this.#queued;
    if (this.#active || !queued) return;

    this.#queued = undefined;
    this.#start(queued);
  }

  #rejectAll(error: ASTWorkerError): void {
    this.#active?.reject(new ASTClientError(error));
    this.#queued?.reject(new ASTClientError(error));
    this.#active = undefined;
    this.#queued = undefined;
  }
}
