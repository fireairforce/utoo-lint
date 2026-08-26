declare module '*.css';
declare module '*.png' {
  const url: string;
  export default url;
}
declare module '*.svg' {
  const url: string;
  export default url;
}
declare module 'monaco-editor/editor/browser/coreCommands.js';
declare module 'monaco-editor/editor/contrib/find/browser/findController.js';
declare module 'monaco-editor/editor/contrib/hover/browser/hoverContribution.js';
declare module 'monaco-editor/editor/contrib/wordOperations/browser/wordOperations.js';
declare module 'monaco-editor/editor/editor.worker.js';
declare module 'monaco-editor/languages/definitions/javascript/register.js';
declare module 'monaco-editor/languages/definitions/typescript/register.js';
