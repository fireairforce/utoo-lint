import Editor, { type OnMount } from '@monaco-editor/react';
import type { LintDiagnostic, LintResult } from '@utoo/lint-wasm';
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import type { KeyboardEvent as ReactKeyboardEvent } from 'react';
import utooRabbitUrl from '../../../../assets/utoo-lint-mark.svg';
import { LintWorkerClient } from '../features/lint/client';
import {
  diagnosticLabel,
  fileNameForLanguage,
  INITIAL_RULES,
  INITIAL_SOURCES,
  LANGUAGES,
  monacoLanguageForLanguage,
  parseRules,
  RECOMMENDED_RULES,
  type PlaygroundLanguage,
} from '../features/playground/model';
import '../features/playground/monaco';
import '../style.css';

type EditorInstance = Parameters<OnMount>[0];
type MonacoInstance = Parameters<OnMount>[1];
type RulesMode = 'recommended' | 'custom';
type RunPhase = 'idle' | 'running' | 'ready' | 'error';

const EDITOR_THEME = 'utoo-dark';

interface RunState {
  phase: RunPhase;
  result?: LintResult;
  message?: string;
  elapsedMs?: number;
}

const EMPTY_RUN_STATE: RunState = { phase: 'idle' };

function defineEditorTheme(monaco: MonacoInstance): void {
  monaco.editor.defineTheme(EDITOR_THEME, {
    base: 'vs-dark',
    inherit: true,
    rules: [
      { token: 'comment', foreground: '66758A', fontStyle: 'italic' },
      { token: 'keyword', foreground: '59B8FF' },
      { token: 'number', foreground: 'C5A7FF' },
      { token: 'string', foreground: 'F2A875' },
      { token: 'type.identifier', foreground: '63D5D0' },
    ],
    colors: {
      'editor.background': '#0B121B',
      'editor.foreground': '#D8E2EE',
      'editorCursor.foreground': '#49B7FF',
      'editorGutter.background': '#0B121B',
      'editorIndentGuide.background1': '#1B2937',
      'editorIndentGuide.activeBackground1': '#34485B',
      'editorLineNumber.activeForeground': '#AFC1D5',
      'editorLineNumber.foreground': '#4C5C70',
      'editor.lineHighlightBackground': '#111C28',
      'editor.selectionBackground': '#174A6A',
      'editor.inactiveSelectionBackground': '#17364B',
      'editorWhitespace.foreground': '#26384A',
      'editorError.foreground': '#FF7081',
      'editorWarning.foreground': '#F5BD55',
    },
  });
}

function diagnosticButtonLabel(diagnostic: LintDiagnostic): string {
  const fixable = diagnostic.fixes.length > 0 ? ', fixable' : '';
  const location = diagnosticLabel(diagnostic);
  return `${diagnostic.severity}: ${diagnostic.message} ${diagnostic.ruleId} ${location}${fixable}`;
}

export default function PlaygroundPage() {
  const [language, setLanguage] =
    useState<PlaygroundLanguage>('typescript');
  const [sources, setSources] =
    useState<Record<PlaygroundLanguage, string>>(INITIAL_SOURCES);
  const [rulesMode, setRulesMode] = useState<RulesMode>('custom');
  const [rulesSource, setRulesSource] = useState(INITIAL_RULES);
  const [runState, setRunState] = useState<RunState>(EMPTY_RUN_STATE);
  const editorRef = useRef<EditorInstance | null>(null);
  const monacoRef = useRef<MonacoInstance | null>(null);
  const clientRef = useRef<LintWorkerClient | null>(null);
  const languageTabRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const latestRequestRef = useRef(0);

  if (!clientRef.current) clientRef.current = new LintWorkerClient();

  const parsedRules = useMemo(() => parseRules(rulesSource), [rulesSource]);
  const source = sources[language];
  const fileName = fileNameForLanguage(language);
  const monacoLanguage = monacoLanguageForLanguage(language);

  const execute = useCallback(
    async (
      action: 'lint' | 'fix',
      requestId = ++latestRequestRef.current,
    ) => {
      if (requestId !== latestRequestRef.current) return;

      if (rulesMode === 'custom' && !parsedRules.ok) {
        setRunState({ phase: 'error', message: parsedRules.message });
        return;
      }

      const startedAt = performance.now();
      setRunState({ phase: 'running' });

      try {
        const result = await clientRef.current?.run(action, source, {
          filePath: fileName,
          rules:
            rulesMode === 'recommended'
              ? RECOMMENDED_RULES
              : parsedRules.ok
                ? parsedRules.rules
                : {},
        });

        if (!result || requestId !== latestRequestRef.current) return;

        if (action === 'fix' && result.mode === 'fix' && result.fixed) {
          setSources((current) => ({
            ...current,
            [language]: result.output,
          }));
        }

        setRunState({
          phase: 'ready',
          result,
          elapsedMs: performance.now() - startedAt,
        });
      } catch (error) {
        if (requestId !== latestRequestRef.current) return;
        setRunState({
          phase: 'error',
          message: error instanceof Error ? error.message : 'Lint failed.',
          elapsedMs: performance.now() - startedAt,
        });
      }
    },
    [fileName, language, parsedRules, rulesMode, source],
  );

  useEffect(() => {
    const requestId = ++latestRequestRef.current;
    setRunState(EMPTY_RUN_STATE);
    const timeout = window.setTimeout(
      () => void execute('lint', requestId),
      220,
    );
    return () => window.clearTimeout(timeout);
  }, [execute]);

  useEffect(() => {
    return () => {
      latestRequestRef.current += 1;
      clientRef.current?.dispose();
    };
  }, []);

  const diagnostics = runState.result?.diagnostics ?? [];
  const suppressedDiagnostics =
    runState.result?.suppressedDiagnostics ?? [];
  const errorCount = diagnostics.filter(
    (diagnostic) => diagnostic.severity === 'error',
  ).length;
  const warningCount = diagnostics.length - errorCount;

  const applyMarkers = useCallback(
    (editor: EditorInstance, monaco: MonacoInstance) => {
      const model = editor.getModel();
      if (!model) return;

      monaco.editor.setModelMarkers(
        model,
        'utoo-lint',
        diagnostics.map((diagnostic) => ({
          code: diagnostic.ruleId,
          message: diagnostic.message,
          severity:
            diagnostic.severity === 'error'
              ? monaco.MarkerSeverity.Error
              : monaco.MarkerSeverity.Warning,
          startLineNumber: diagnostic.line,
          startColumn: diagnostic.column,
          endLineNumber: diagnostic.endLine,
          endColumn:
            diagnostic.endLine === diagnostic.line &&
            diagnostic.endColumn <= diagnostic.column
              ? diagnostic.column + 1
              : diagnostic.endColumn,
          source: 'utoo-lint',
        })),
      );
    },
    [diagnostics],
  );

  useEffect(() => {
    if (editorRef.current && monacoRef.current) {
      applyMarkers(editorRef.current, monacoRef.current);
    }
  }, [applyMarkers]);

  const handleEditorMount: OnMount = (editor, monaco) => {
    editorRef.current = editor;
    monacoRef.current = monaco;
    applyMarkers(editor, monaco);
  };

  const handleEditorBeforeMount = (monaco: MonacoInstance) => {
    defineEditorTheme(monaco);
  };

  const revealDiagnostic = (diagnostic: LintDiagnostic) => {
    const editor = editorRef.current;
    if (!editor) return;
    editor.setPosition({
      lineNumber: diagnostic.line,
      column: diagnostic.column,
    });
    editor.revealPositionInCenter({
      lineNumber: diagnostic.line,
      column: diagnostic.column,
    });
    editor.focus();
  };

  const selectLanguage = (nextLanguage: PlaygroundLanguage) => {
    setRunState(EMPTY_RUN_STATE);
    setLanguage(nextLanguage);
  };

  const handleLanguageTabKeyDown = (
    event: ReactKeyboardEvent<HTMLButtonElement>,
    index: number,
  ) => {
    let nextIndex: number;

    switch (event.key) {
      case 'ArrowRight':
        nextIndex = (index + 1) % LANGUAGES.length;
        break;
      case 'ArrowLeft':
        nextIndex = (index - 1 + LANGUAGES.length) % LANGUAGES.length;
        break;
      case 'Home':
        nextIndex = 0;
        break;
      case 'End':
        nextIndex = LANGUAGES.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    selectLanguage(LANGUAGES[nextIndex].id);
    languageTabRefs.current[nextIndex]?.focus();
  };

  const canFix =
    runState.phase === 'ready' &&
    diagnostics.some((diagnostic) => diagnostic.fixes.length > 0);
  const hasValidRules = rulesMode === 'recommended' || parsedRules.ok;
  const isRetry = runState.phase === 'error';
  const hasCustomRulesError = rulesMode === 'custom' && !parsedRules.ok;
  const rulesDescriptionId = hasCustomRulesError
    ? 'rules-config-error'
    : rulesMode === 'recommended'
      ? 'rules-mode-note'
      : undefined;

  return (
    <main className="playground-shell">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            <img alt="" height={40} src={utooRabbitUrl} width={28} />
          </span>
          <div className="brand-copy">
            <div className="brand-title">
              <h1>utoo-lint</h1>
              <span aria-hidden="true" className="brand-separator">
                /
              </span>
              <span>Playground</span>
            </div>
            <span className="brand-caption">
              Fast linting, powered by WebAssembly
            </span>
          </div>
        </div>

        <div className="header-actions">
          <div className="runtime-badges" aria-label="Runtime stack">
            <span>EVJS</span>
            <span>Utoopack</span>
            <span>WebAssembly</span>
          </div>

          <a
            aria-label="Open utoo-lint on GitHub (opens in a new tab)"
            className="github-link"
            href="https://github.com/utooland/utoo-lint"
            target="_blank"
            rel="noreferrer"
          >
            <span>GitHub</span>
            <svg aria-hidden="true" viewBox="0 0 20 20">
              <path d="M7 13 13 7M8 7h5v5" />
            </svg>
          </a>
        </div>
      </header>

      <section className="controlbar" aria-label="Playground controls">
        <div className="language-control">
          <span className="control-label">Language</span>
          <div
            aria-label="Language"
            aria-orientation="horizontal"
            className="language-tabs"
            role="tablist"
          >
            {LANGUAGES.map((item, index) => (
              <button
                aria-controls="source-editor-panel"
                aria-selected={item.id === language}
                className={item.id === language ? 'is-active' : undefined}
                id={`language-tab-${item.id}`}
                key={item.id}
                onClick={() => selectLanguage(item.id)}
                onKeyDown={(event) => handleLanguageTabKeyDown(event, index)}
                ref={(element) => {
                  languageTabRefs.current[index] = element;
                }}
                role="tab"
                tabIndex={item.id === language ? 0 : -1}
                type="button"
              >
                {item.label}
              </button>
            ))}
          </div>
        </div>

        <div className="run-summary" aria-live="polite">
          <span
            aria-hidden="true"
            className={`status-dot status-${runState.phase}`}
          />
          <span className="run-state-copy">
            {runState.phase === 'idle' && 'Queued…'}
            {runState.phase === 'running' && 'Linting…'}
            {runState.phase === 'ready' &&
              `Ready · ${runState.elapsedMs?.toFixed(1)} ms`}
            {runState.phase === 'error' && 'Run failed'}
          </span>
          <span className="summary-count error-count">{errorCount} errors</span>
          <span className="summary-count warning-count">
            {warningCount} warnings
          </span>
        </div>

        <button
          className="fix-button"
          disabled={isRetry ? !hasValidRules : !canFix}
          onClick={() => void execute(isRetry ? 'lint' : 'fix')}
          type="button"
        >
          <svg aria-hidden="true" viewBox="0 0 20 20">
            <path d="m4.5 10.2 3.4 3.4 7.6-7.7" />
          </svg>
          <span>{isRetry ? 'Retry' : 'Fix all'}</span>
        </button>
      </section>

      <section className="workspace">
        <div
          aria-labelledby={`language-tab-${language}`}
          className="editor-panel"
          id="source-editor-panel"
          role="tabpanel"
        >
          <div className="panel-heading">
            <span className="panel-title file-name">{fileName}</span>
            <span className="panel-hint">
              <span aria-hidden="true" className="auto-lint-dot" />
              Auto lint
            </span>
          </div>
          <div className="editor-frame">
            <Editor
              beforeMount={handleEditorBeforeMount}
              height="100%"
              language={monacoLanguage}
              onChange={(value) => {
                setRunState(EMPTY_RUN_STATE);
                setSources((current) => ({
                  ...current,
                  [language]: value ?? '',
                }));
              }}
              onMount={handleEditorMount}
              path={fileName}
              theme={EDITOR_THEME}
              value={source}
              options={{
                ariaLabel: `${fileName} source editor`,
                automaticLayout: true,
                bracketPairColorization: { enabled: true },
                fontFamily:
                  "'SFMono-Regular', Consolas, 'Liberation Mono', monospace",
                fontLigatures: true,
                fontSize: 14,
                lineHeight: 22,
                minimap: { enabled: false },
                padding: { top: 16 },
                renderLineHighlight: 'gutter',
                scrollBeyondLastLine: false,
                smoothScrolling: true,
                tabSize: 2,
              }}
            />
          </div>
        </div>

        <aside
          aria-label="Lint configuration and diagnostics"
          className="side-panel"
        >
          <section
            aria-labelledby="rules-panel-title"
            className="rules-section"
          >
            <div className="panel-heading rules-heading">
              <h2 className="panel-title" id="rules-panel-title">
                Rules <span className="panel-subtitle">JSON config</span>
              </h2>
              <div className="segmented-control">
                <button
                  aria-pressed={rulesMode === 'recommended'}
                  className={rulesMode === 'recommended' ? 'is-active' : undefined}
                  onClick={() => {
                    setRunState(EMPTY_RUN_STATE);
                    setRulesMode('recommended');
                  }}
                  type="button"
                >
                  Recommended
                </button>
                <button
                  aria-pressed={rulesMode === 'custom'}
                  className={rulesMode === 'custom' ? 'is-active' : undefined}
                  onClick={() => {
                    setRunState(EMPTY_RUN_STATE);
                    setRulesMode('custom');
                  }}
                  type="button"
                >
                  Custom
                </button>
              </div>
            </div>
            <textarea
              aria-describedby={rulesDescriptionId}
              aria-invalid={hasCustomRulesError || undefined}
              aria-label="Rule configuration JSON"
              className={`rules-editor ${hasCustomRulesError ? 'has-error' : ''}`}
              disabled={rulesMode === 'recommended'}
              onChange={(event) => {
                setRunState(EMPTY_RUN_STATE);
                setRulesSource(event.target.value);
              }}
              spellCheck={false}
              value={rulesMode === 'recommended' ? INITIAL_RULES : rulesSource}
            />
            {hasCustomRulesError && (
              <p className="config-error" id="rules-config-error" role="alert">
                {parsedRules.message}
              </p>
            )}
            {rulesMode === 'recommended' && (
              <p className="rules-note" id="rules-mode-note">
                Using the Playground&apos;s curated browser-safe rule set.
              </p>
            )}
          </section>

          <section
            aria-busy={runState.phase === 'idle' || runState.phase === 'running'}
            aria-labelledby="diagnostics-panel-title"
            className="diagnostics-section"
          >
            <div className="panel-heading">
              <h2 className="panel-title" id="diagnostics-panel-title">
                Diagnostics
              </h2>
              <span className="diagnostic-total">{diagnostics.length}</span>
            </div>

            <div className="diagnostic-list">
              {runState.phase === 'error' && (
                <div className="empty-state error-state" role="alert">
                  <strong>Unable to lint</strong>
                  <span>{runState.message}</span>
                </div>
              )}

              {(runState.phase === 'idle' || runState.phase === 'running') && (
                <div className="empty-state">
                  <span className="loading-icon" aria-hidden="true">
                    ···
                  </span>
                  <strong>
                    {runState.phase === 'idle' ? 'Lint queued' : 'Linting…'}
                  </strong>
                  <span>Results will appear when the worker is ready.</span>
                </div>
              )}

              {runState.phase === 'ready' && diagnostics.length === 0 && (
                <div className="empty-state">
                  <span className="success-icon" aria-hidden="true">
                    ✓
                  </span>
                  <strong>No diagnostics</strong>
                  <span>This file is clean for the selected rules.</span>
                </div>
              )}

              {diagnostics.map((diagnostic, index) => (
                <button
                  aria-label={diagnosticButtonLabel(diagnostic)}
                  className={`diagnostic-card severity-${diagnostic.severity}`}
                  key={`${diagnostic.ruleId}-${diagnostic.range[0]}-${index}`}
                  onClick={() => revealDiagnostic(diagnostic)}
                  type="button"
                >
                  <span className="severity-symbol" aria-hidden="true">
                    {diagnostic.severity === 'error' ? '×' : '!'}
                  </span>
                  <span className="diagnostic-content">
                    <span className="diagnostic-message">
                      {diagnostic.message}
                    </span>
                    <span className="diagnostic-meta">
                      <code>{diagnostic.ruleId}</code>
                      <span>{diagnosticLabel(diagnostic)}</span>
                      {diagnostic.fixes.length > 0 && (
                        <span className="fixable-badge">fixable</span>
                      )}
                    </span>
                  </span>
                </button>
              ))}
            </div>

            {suppressedDiagnostics.length > 0 && (
              <div className="notice-row">
                {suppressedDiagnostics.length} suppressed diagnostic
                {suppressedDiagnostics.length === 1 ? '' : 's'}
              </div>
            )}

            {(runState.result?.skippedRules.length ?? 0) > 0 && (
              <div className="notice-row warning-notice">
                <strong>Project context unavailable</strong>
                <span>
                  Skipped: {runState.result?.skippedRules.join(', ')}
                </span>
              </div>
            )}
          </section>
        </aside>
      </section>

      <footer className="footer-note">
        <span aria-hidden="true" className="privacy-dot" />
        <span>Runs locally in your browser</span>
        <span aria-hidden="true" className="footer-separator">
          ·
        </span>
        <span>Single-file linting</span>
        <span aria-hidden="true" className="footer-separator">
          ·
        </span>
        <span>Project rules may be skipped</span>
      </footer>
    </main>
  );
}
