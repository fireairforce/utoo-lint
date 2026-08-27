import Editor, { type OnMount } from '@monaco-editor/react';
import type { LintDiagnostic, LintResult } from '@utoo/lint-wasm';
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import type {
  CSSProperties,
  KeyboardEvent as ReactKeyboardEvent,
} from 'react';
import utooRabbitUrl from '../../../../assets/utoo-lint-mark-gpt.png';
import { ASTWorkerClient } from '../features/ast/client';
import type { ASTParseResult } from '../features/ast/protocol';
import { ASTTree } from '../features/ast/tree';
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
import { Splitter } from '../features/playground/splitter';
import '../style.css';

type EditorInstance = Parameters<OnMount>[0];
type MonacoInstance = Parameters<OnMount>[1];
type InspectorMode = 'ast' | 'rules';
type RulesMode = 'recommended' | 'custom';
type ASTPhase = 'idle' | 'running' | 'ready' | 'error';
type RunPhase = 'idle' | 'running' | 'ready' | 'error';
type ShareState = 'idle' | 'copied' | 'error';

const EDITOR_THEME = 'utoo-dark';
const DEFAULT_EDITOR_RATIO = 68;
const DEFAULT_RULES_RATIO = 42;
const INSPECTOR_MODES = ['rules', 'ast'] as const;
const V030_WASM_URL = new URL(
  '../../../../npm/@utoo/lint-wasm/utoo-lint.wasm',
  import.meta.url,
).href;
const LINT_VERSIONS = [
  { id: '0.3.0', label: 'v0.3.0', wasmUrl: V030_WASM_URL },
] as const;

type LintVersionId = (typeof LINT_VERSIONS)[number]['id'];

function getLintVersionDefinition(version: LintVersionId) {
  return (
    LINT_VERSIONS.find((candidate) => candidate.id === version) ??
    LINT_VERSIONS[0]
  );
}

function getInitialLintVersion(): LintVersionId {
  if (typeof window === 'undefined') return LINT_VERSIONS[0].id;
  const requestedVersion = new URLSearchParams(window.location.search).get(
    'version',
  );
  const match = LINT_VERSIONS.find(
    (candidate) => candidate.id === requestedVersion,
  );
  return match?.id ?? LINT_VERSIONS[0].id;
}

interface RunState {
  phase: RunPhase;
  result?: LintResult;
  message?: string;
  elapsedMs?: number;
}

interface ASTState {
  message?: string;
  phase: ASTPhase;
  result?: ASTParseResult;
  revision: number;
}

const EMPTY_RUN_STATE: RunState = { phase: 'idle' };
const EMPTY_AST_STATE: ASTState = { phase: 'idle', revision: 0 };

function defineEditorTheme(monaco: MonacoInstance): void {
  monaco.editor.defineTheme(EDITOR_THEME, {
    base: 'vs-dark',
    inherit: true,
    rules: [
      { token: 'comment', foreground: '8B949E' },
      { token: 'keyword', foreground: 'FF7B72' },
      { token: 'number', foreground: '79C0FF' },
      { token: 'string', foreground: 'A5D6FF' },
      { token: 'type.identifier', foreground: 'D2A8FF' },
    ],
    colors: {
      'editor.background': '#101216',
      'editor.foreground': '#D6DAE1',
      'editorCursor.foreground': '#38BDF8',
      'editorGutter.background': '#101216',
      'editorIndentGuide.background1': '#232830',
      'editorIndentGuide.activeBackground1': '#373E49',
      'editorLineNumber.activeForeground': '#C7CDD6',
      'editorLineNumber.foreground': '#626A76',
      'editor.lineHighlightBackground': '#181B21',
      'editor.selectionBackground': '#164B68',
      'editor.inactiveSelectionBackground': '#15394C',
      'editorWhitespace.foreground': '#2A3038',
      'editorError.foreground': '#F85149',
      'editorWarning.foreground': '#D29922',
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
  const [lintVersion, setLintVersion] = useState<LintVersionId>(
    getInitialLintVersion,
  );
  const [sources, setSources] =
    useState<Record<PlaygroundLanguage, string>>(INITIAL_SOURCES);
  const [inspectorMode, setInspectorMode] =
    useState<InspectorMode>('rules');
  const [rulesMode, setRulesMode] = useState<RulesMode>('custom');
  const [rulesSource, setRulesSource] = useState(INITIAL_RULES);
  const [runState, setRunState] = useState<RunState>(EMPTY_RUN_STATE);
  const [astState, setASTState] = useState<ASTState>(EMPTY_AST_STATE);
  const [shareState, setShareState] = useState<ShareState>('idle');
  const editorRef = useRef<EditorInstance | null>(null);
  const monacoRef = useRef<MonacoInstance | null>(null);
  const astClientRef = useRef<ASTWorkerClient | null>(null);
  const clientRef = useRef<LintWorkerClient | null>(null);
  const workspaceRef = useRef<HTMLElement | null>(null);
  const sidePanelRef = useRef<HTMLElement | null>(null);
  const shareResetTimerRef = useRef<number | undefined>(undefined);
  const latestASTRequestRef = useRef(0);
  const latestRequestRef = useRef(0);
  const [editorRatio, setEditorRatio] = useState(DEFAULT_EDITOR_RATIO);
  const [rulesRatio, setRulesRatio] = useState(DEFAULT_RULES_RATIO);

  if (!clientRef.current) clientRef.current = new LintWorkerClient();
  if (!astClientRef.current) astClientRef.current = new ASTWorkerClient();

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
        const result = await clientRef.current?.run(
          action,
          source,
          {
            filePath: fileName,
            rules:
              rulesMode === 'recommended'
                ? RECOMMENDED_RULES
                : parsedRules.ok
                  ? parsedRules.rules
                  : {},
          },
          getLintVersionDefinition(lintVersion).wasmUrl,
        );

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
    [fileName, language, lintVersion, parsedRules, rulesMode, source],
  );

  useEffect(() => {
    const requestId = ++latestRequestRef.current;
    clientRef.current?.cancelQueued();
    setRunState(EMPTY_RUN_STATE);
    const timeout = window.setTimeout(
      () => void execute('lint', requestId),
      220,
    );
    return () => window.clearTimeout(timeout);
  }, [execute]);

  useEffect(() => {
    if (inspectorMode !== 'ast') return;

    const requestId = ++latestASTRequestRef.current;
    astClientRef.current?.cancelQueued();
    setASTState({ phase: 'idle', revision: requestId });
    const timeout = window.setTimeout(() => {
      setASTState({ phase: 'running', revision: requestId });
      void astClientRef.current
        ?.parse(source, fileName)
        .then((result) => {
          if (requestId !== latestASTRequestRef.current) return;
          setASTState({ phase: 'ready', result, revision: requestId });
        })
        .catch((error: unknown) => {
          if (requestId !== latestASTRequestRef.current) return;
          setASTState({
            message: error instanceof Error ? error.message : 'AST parsing failed.',
            phase: 'error',
            revision: requestId,
          });
        });
    }, 220);

    return () => {
      window.clearTimeout(timeout);
      if (latestASTRequestRef.current === requestId) {
        latestASTRequestRef.current += 1;
      }
      astClientRef.current?.cancelQueued();
    };
  }, [fileName, inspectorMode, source]);

  useEffect(() => {
    return () => {
      latestASTRequestRef.current += 1;
      latestRequestRef.current += 1;
      window.clearTimeout(shareResetTimerRef.current);
      astClientRef.current?.dispose();
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

  const revealASTNode = (start: number, end: number) => {
    const editor = editorRef.current;
    const model = editor?.getModel();
    if (!editor || !model) return;

    // Yuku exposes UTF-16 offsets here, matching Monaco's model API.
    const startPosition = model.getPositionAt(start);
    const endPosition = model.getPositionAt(end);
    const range = {
      endColumn: endPosition.column,
      endLineNumber: endPosition.lineNumber,
      startColumn: startPosition.column,
      startLineNumber: startPosition.lineNumber,
    };
    editor.setSelection(range);
    editor.revealRangeInCenter(range);
  };

  const selectLanguage = (nextLanguage: PlaygroundLanguage) => {
    setRunState(EMPTY_RUN_STATE);
    setLanguage(nextLanguage);
  };

  const selectLintVersion = (nextVersion: string) => {
    const definition = LINT_VERSIONS.find(
      (candidate) => candidate.id === nextVersion,
    );
    if (!definition || definition.id === lintVersion) return;

    setRunState(EMPTY_RUN_STATE);
    setLintVersion(definition.id);
    const url = new URL(window.location.href);
    url.searchParams.set('version', definition.id);
    window.history.replaceState(null, '', url);
  };

  const sharePlayground = async () => {
    const shareData = {
      title: 'Playground | Utoo Lint',
      text: 'Playground of Utoo Lint',
      url: window.location.href,
    };

    try {
      if (navigator.share) {
        await navigator.share(shareData);
      } else {
        await navigator.clipboard.writeText(shareData.url);
      }
      setShareState('copied');
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') return;
      setShareState('error');
    }

    window.clearTimeout(shareResetTimerRef.current);
    shareResetTimerRef.current = window.setTimeout(
      () => setShareState('idle'),
      1800,
    );
  };

  const handleInspectorTabKeyDown = (
    event: ReactKeyboardEvent<HTMLButtonElement>,
    index: number,
  ) => {
    let nextIndex: number;

    switch (event.key) {
      case 'ArrowRight':
        nextIndex = (index + 1) % INSPECTOR_MODES.length;
        break;
      case 'ArrowLeft':
        nextIndex = (index - 1 + INSPECTOR_MODES.length) %
          INSPECTOR_MODES.length;
        break;
      case 'Home':
        nextIndex = 0;
        break;
      case 'End':
        nextIndex = INSPECTOR_MODES.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    setInspectorMode(INSPECTOR_MODES[nextIndex]);
    const tabs = event.currentTarget.parentElement?.querySelectorAll('button');
    tabs?.[nextIndex]?.focus();
  };

  const fixableCount = diagnostics.filter(
    (diagnostic) => diagnostic.fixes.length > 0,
  ).length;
  const canFix = runState.phase === 'ready' && fixableCount > 0;
  const hasValidRules = rulesMode === 'recommended' || parsedRules.ok;
  const isRetry = runState.phase === 'error';
  const hasCustomRulesError = rulesMode === 'custom' && !parsedRules.ok;
  const fixButtonText = isRetry
    ? 'Retry'
    : canFix && fixableCount < diagnostics.length
      ? `Fix ${fixableCount}`
      : 'Fix all';
  const fixButtonLabel = isRetry
    ? 'Retry lint'
    : canFix
      ? fixableCount === diagnostics.length
        ? `Fix all ${fixableCount} diagnostics`
        : `Fix ${fixableCount} of ${diagnostics.length} diagnostics with safe autofixes`
      : 'No safe autofixes available';
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
          <div className="brand-title">
            <h1>utoo-lint</h1>
          </div>
        </div>

        <section className="controlbar" aria-label="Playground controls">
          <label className="language-select-control">
            <span className="language-select-label">Language</span>
            <span className="language-select-wrap">
              <select
                aria-controls="source-editor-panel"
                onChange={(event) =>
                  selectLanguage(event.target.value as PlaygroundLanguage)
                }
                value={language}
              >
                {LANGUAGES.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.label}
                  </option>
                ))}
              </select>
            </span>
          </label>

          <div className="run-summary" aria-hidden="true">
            <span
              className={`run-state-copy run-state-${runState.phase}`}
            >
              {runState.phase === 'idle' && 'Queued…'}
              {runState.phase === 'running' && 'Linting…'}
              {runState.phase === 'ready' && 'Ready'}
              {runState.phase === 'error' && 'Run failed'}
            </span>
            {runState.phase === 'ready' && (
              <span className="run-duration">
                {runState.elapsedMs?.toFixed(1)} ms
              </span>
            )}
            <span className="summary-count error-count">
              <strong>{errorCount}</strong>{' '}
              {errorCount === 1 ? 'error' : 'errors'}
            </span>
            <span className="summary-count warning-count">
              <strong>{warningCount}</strong>{' '}
              {warningCount === 1 ? 'warning' : 'warnings'}
            </span>
          </div>

          <span
            aria-atomic="true"
            className="run-announcement"
            role="status"
          >
            {runState.phase === 'idle' && 'Lint queued.'}
            {runState.phase === 'running' && 'Linting.'}
            {runState.phase === 'ready' &&
              `Lint complete. ${errorCount} ${errorCount === 1 ? 'error' : 'errors'}, ${warningCount} ${warningCount === 1 ? 'warning' : 'warnings'}.`}
            {runState.phase === 'error' &&
              `Lint failed${runState.message ? `: ${runState.message}` : '.'}`}
          </span>

          <span aria-hidden="true" className="toolbar-divider" />

          <button
            aria-label={fixButtonLabel}
            className="fix-button"
            disabled={isRetry ? !hasValidRules : !canFix}
            onClick={() => void execute(isRetry ? 'lint' : 'fix')}
            title={fixButtonLabel}
            type="button"
          >
            {fixButtonText}
          </button>

          <label className="version-control">
            <span className="visually-hidden">Utoo Lint version</span>
            <select
              aria-label="Utoo Lint version"
              onChange={(event) => selectLintVersion(event.target.value)}
              value={lintVersion}
            >
              {LINT_VERSIONS.map((version) => (
                <option key={version.id} value={version.id}>
                  {version.label}
                </option>
              ))}
            </select>
          </label>

          <button
            aria-label="Share this playground"
            className="share-button"
            onClick={() => void sharePlayground()}
            type="button"
          >
            <span aria-live="polite">
              {shareState === 'idle' && 'Share'}
              {shareState === 'copied' && 'Copied'}
              {shareState === 'error' && 'Copy failed'}
            </span>
          </button>

          <a
            aria-label="Open utoo-lint on GitHub (opens in a new tab)"
            className="github-link"
            href="https://github.com/utooland/utoo-lint"
            target="_blank"
            rel="noreferrer"
          >
            GitHub
            <span aria-hidden="true" className="external-mark">
              ↗
            </span>
          </a>
        </section>
      </header>

      <section
        className="workspace"
        ref={workspaceRef}
        style={{ '--editor-ratio': `${editorRatio}%` } as CSSProperties}
      >
        <div
          aria-label={`${fileName} source editor panel`}
          className="editor-panel"
          id="source-editor-panel"
        >
          <div className="panel-heading">
            <div className="panel-heading-copy">
              <span className="panel-kicker">Source</span>
              <span className="panel-title file-name">{fileName}</span>
            </div>
            <span className="panel-hint">Live lint</span>
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
                fontSize: 16,
                lineHeight: 25,
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

        <Splitter
          ariaControls="source-editor-panel lint-side-panel"
          ariaLabel="Resize source editor and lint sidebar"
          containerRef={workspaceRef}
          minPrimaryPx={480}
          minSecondaryPx={340}
          onChange={setEditorRatio}
          onReset={() => setEditorRatio(DEFAULT_EDITOR_RATIO)}
          orientation="vertical"
          value={editorRatio}
        />

        <aside
          aria-label="Lint configuration and diagnostics"
          className="side-panel"
          id="lint-side-panel"
          ref={sidePanelRef}
          style={{ '--rules-ratio': `${rulesRatio}%` } as CSSProperties}
        >
          <section
            aria-label="Source inspector"
            className="rules-section"
            id="rules-panel"
          >
            <div className="panel-heading rules-heading">
              <div
                aria-label="Inspector view"
                className="inspector-tabs"
                role="tablist"
              >
                <button
                  aria-controls="rules-config-panel"
                  aria-selected={inspectorMode === 'rules'}
                  className={inspectorMode === 'rules' ? 'is-active' : undefined}
                  id="inspector-tab-rules"
                  onClick={() => setInspectorMode('rules')}
                  onKeyDown={(event) => handleInspectorTabKeyDown(event, 0)}
                  role="tab"
                  tabIndex={inspectorMode === 'rules' ? 0 : -1}
                  type="button"
                >
                  utlint.json
                </button>
                <button
                  aria-controls="ast-panel"
                  aria-selected={inspectorMode === 'ast'}
                  className={inspectorMode === 'ast' ? 'is-active' : undefined}
                  id="inspector-tab-ast"
                  onClick={() => setInspectorMode('ast')}
                  onKeyDown={(event) => handleInspectorTabKeyDown(event, 1)}
                  role="tab"
                  tabIndex={inspectorMode === 'ast' ? 0 : -1}
                  type="button"
                >
                  AST
                </button>
              </div>

              {inspectorMode === 'rules' ? (
                <div className="segmented-control">
                  <span className="segmented-label">Ruleset</span>
                  <button
                    aria-pressed={rulesMode === 'recommended'}
                    className={
                      rulesMode === 'recommended' ? 'is-active' : undefined
                    }
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
              ) : (
                <span className="ast-status">
                  {astState.phase === 'idle' && 'Queued'}
                  {astState.phase === 'running' && 'Parsing…'}
                  {astState.phase === 'ready' &&
                    `${astState.result?.elapsedMs.toFixed(1)} ms`}
                  {astState.phase === 'error' && 'Parse failed'}
                </span>
              )}
            </div>

            {inspectorMode === 'rules' ? (
              <div
                aria-labelledby="inspector-tab-rules"
                className="rules-config-panel"
                id="rules-config-panel"
                role="tabpanel"
              >
                <textarea
                  aria-describedby={rulesDescriptionId}
                  aria-invalid={hasCustomRulesError || undefined}
                  aria-label="utlint.json configuration"
                  className={`rules-editor ${hasCustomRulesError ? 'has-error' : ''}`}
                  disabled={rulesMode === 'recommended'}
                  onChange={(event) => {
                    setRunState(EMPTY_RUN_STATE);
                    setRulesSource(event.target.value);
                  }}
                  spellCheck={false}
                  value={
                    rulesMode === 'recommended' ? INITIAL_RULES : rulesSource
                  }
                />
                {hasCustomRulesError && (
                  <p
                    className="config-error"
                    id="rules-config-error"
                    role="alert"
                  >
                    {parsedRules.message}
                  </p>
                )}
                {rulesMode === 'recommended' && (
                  <p className="rules-note" id="rules-mode-note">
                    Using the Playground&apos;s curated browser-safe rule set.
                  </p>
                )}
              </div>
            ) : (
              <div
                aria-busy={
                  astState.phase === 'idle' || astState.phase === 'running'
                }
                aria-labelledby="inspector-tab-ast"
                className="ast-panel"
                id="ast-panel"
                role="tabpanel"
              >
                {astState.phase === 'error' && (
                  <div className="empty-state error-state" role="alert">
                    <strong>Unable to parse AST</strong>
                    <span>{astState.message}</span>
                  </div>
                )}
                {(astState.phase === 'idle' ||
                  astState.phase === 'running') && (
                  <div className="empty-state ast-loading-state">
                    <span className="loading-icon" aria-hidden="true">
                      ···
                    </span>
                    <strong>
                      {astState.phase === 'idle'
                        ? 'AST queued'
                        : 'Parsing AST…'}
                    </strong>
                  </div>
                )}
                {astState.phase === 'ready' && astState.result && (
                  <>
                    {astState.result.diagnostics.length > 0 && (
                      <div className="ast-diagnostic-note">
                        {astState.result.diagnostics.length} parser diagnostic
                        {astState.result.diagnostics.length === 1 ? '' : 's'}
                      </div>
                    )}
                    <ASTTree
                      key={astState.revision}
                      onSelect={revealASTNode}
                      program={astState.result.program}
                    />
                  </>
                )}
              </div>
            )}
          </section>

          <Splitter
            ariaControls="rules-panel diagnostics-panel"
            ariaLabel="Resize rules and diagnostics panels"
            containerRef={sidePanelRef}
            minPrimaryPx={180}
            minSecondaryPx={220}
            onChange={setRulesRatio}
            onReset={() => setRulesRatio(DEFAULT_RULES_RATIO)}
            orientation="horizontal"
            value={rulesRatio}
          />

          <section
            aria-busy={runState.phase === 'idle' || runState.phase === 'running'}
            aria-labelledby="diagnostics-panel-title"
            className="diagnostics-section"
            id="diagnostics-panel"
          >
            <div className="panel-heading">
              <div className="panel-heading-copy">
                <span className="panel-kicker">Output</span>
                <h2 className="panel-title" id="diagnostics-panel-title">
                  Diagnostics
                </h2>
              </div>
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

    </main>
  );
}
