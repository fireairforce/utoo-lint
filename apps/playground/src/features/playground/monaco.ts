import { loader } from '@monaco-editor/react';
import * as monaco from 'monaco-editor/editor/editor.api.js';
import 'monaco-editor/editor/browser/coreCommands.js';
import 'monaco-editor/editor/contrib/find/browser/findController.js';
import 'monaco-editor/editor/contrib/hover/browser/hoverContribution.js';
import 'monaco-editor/editor/contrib/wordOperations/browser/wordOperations.js';
import 'monaco-editor/languages/definitions/javascript/register.js';
import 'monaco-editor/languages/definitions/typescript/register.js';

interface MonacoWorkerEnvironment {
  MonacoEnvironment?: {
    getWorker(moduleId: string, label: string): Worker;
  };
}

const workerEnvironment = self as unknown as MonacoWorkerEnvironment;

workerEnvironment.MonacoEnvironment = {
  getWorker() {
    return new Worker(
      new URL('./editor.worker.ts', import.meta.url),
      { name: 'monaco-editor', type: 'module' },
    );
  },
};

loader.config({ monaco });
