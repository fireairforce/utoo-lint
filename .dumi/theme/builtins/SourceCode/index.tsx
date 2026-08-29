import { useLocale, useSiteData } from 'dumi';
import Highlight, { defaultProps, type Language } from 'prism-react-renderer';
import 'prism-themes/themes/prism-one-light.css';
import React, { type ReactNode, useEffect, useRef, useState } from 'react';
import 'dumi/theme-default/builtins/SourceCode/index.less';

interface SourceCodeProps {
  children: string;
  extra?: ReactNode;
  highlightLines?: number[];
  lang: Language;
  textarea?: ReactNode;
}

const similarDsl: Record<string, Language> = {
  acss: 'css',
  axml: 'markup',
  vue: 'markup',
};

async function writeClipboard(text: string) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return;
    } catch {
      // Fall through to the DOM fallback when the Clipboard API is denied.
    }
  }

  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  document.body.append(textarea);
  try {
    textarea.focus();
    textarea.select();
    if (!document.execCommand('copy')) {
      throw new Error('Clipboard copy was rejected');
    }
  } finally {
    textarea.remove();
  }
}

function CopyIcon() {
  return (
    <svg aria-hidden="true" viewBox="64 64 896 896">
      <path d="M768 832H384c-35.3 0-64-28.7-64-64V384c0-35.3 28.7-64 64-64h384c35.3 0 64 28.7 64 64v384c0 35.3-28.7 64-64 64Zm0-448H384v384h384V384ZM640 256H256v384h-64V256c0-35.3 28.7-64 64-64h384v64Z" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg aria-hidden="true" viewBox="64 64 896 896">
      <path d="M438.6 730.9 171.5 463.8a8 8 0 0 1 0-11.3l45.2-45.2a8 8 0 0 1 11.3 0l216.2 216.2L796 271.7a8 8 0 0 1 11.3 0l45.2 45.2a8 8 0 0 1 0 11.3L449.9 730.9a8 8 0 0 1-11.3 0Z" />
    </svg>
  );
}

export default function SourceCode({
  children = '',
  extra,
  highlightLines = [],
  lang,
  textarea,
}: SourceCodeProps) {
  const timer = useRef<number | undefined>(undefined);
  const [copyState, setCopyState] = useState<'idle' | 'copied' | 'failed'>(
    'idle',
  );
  const [text, setText] = useState(children);
  const { themeConfig } = useSiteData();
  const isChinese = useLocale().id === 'zh-CN';

  useEffect(() => {
    setText(
      /shellscript|shell|bash|sh|zsh/.test(lang)
        ? children.replace(/^(\$|>)\s/gm, '')
        : children,
    );
  }, [lang, children]);

  useEffect(
    () => () => {
      if (timer.current) window.clearTimeout(timer.current);
    },
    [],
  );

  const code = (
    <Highlight
      {...defaultProps}
      code={textarea ? children : children.trim()}
      language={similarDsl[lang] || lang}
      theme={undefined}
    >
      {({ className, style, tokens, getLineProps, getTokenProps }) => (
        <pre className={className} style={style}>
          {tokens.map((line, lineIndex) => (
            <div
              className={[
                highlightLines.includes(lineIndex + 1) && 'highlighted',
                themeConfig.showLineNum && 'wrap',
              ]
                .filter(Boolean)
                .join(' ')}
              key={String(lineIndex)}
            >
              {themeConfig.showLineNum && (
                <span aria-hidden="true" className="token-line-num">
                  {lineIndex + 1}
                </span>
              )}
              <div
                {...getLineProps({ line, key: lineIndex })}
                className={themeConfig.showLineNum ? 'line-cell' : undefined}
              >
                {line.map((token, tokenIndex) =>
                  React.createElement(
                    'span',
                    getTokenProps({ token, key: tokenIndex }),
                  ),
                )}
              </div>
            </div>
          ))}
        </pre>
      )}
    </Highlight>
  );
  const copyLabel =
    copyState === 'copied'
      ? isChinese
        ? '代码已复制'
        : 'Code copied'
      : copyState === 'failed'
        ? isChinese
          ? '复制失败'
          : 'Copy failed'
        : isChinese
          ? '复制代码'
          : 'Copy code';

  return (
    <div className="dumi-default-source-code">
      {lang && <span className="dumi-default-source-code-language">{lang}</span>}
      <button
        aria-label={copyLabel}
        className="dumi-default-source-code-copy"
        data-copied={copyState === 'copied' || undefined}
        onClick={async () => {
          try {
            await writeClipboard(text);
            setCopyState('copied');
          } catch {
            setCopyState('failed');
          }
          if (timer.current) window.clearTimeout(timer.current);
          timer.current = window.setTimeout(() => setCopyState('idle'), 2000);
        }}
        title={copyLabel}
        type="button"
      >
        {copyState === 'copied' ? <CheckIcon /> : <CopyIcon />}
      </button>
      <span aria-live="polite" className="utlint-sr-only">
        {copyState === 'idle' ? '' : copyLabel}
      </span>
      {textarea ? (
        <div className="dumi-default-source-code-scroll-container">
          <div className="dumi-default-source-code-scroll-content">
            {code}
            {textarea}
          </div>
        </div>
      ) : (
        code
      )}
      {extra}
    </div>
  );
}
