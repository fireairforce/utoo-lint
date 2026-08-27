import type { LintDiagnostic, RuleConfig } from '@utoo/lint-wasm';

export const LANGUAGES = [
  {
    id: 'typescript',
    label: 'TypeScript',
    fileName: 'index.ts',
    monacoLanguage: 'typescript',
  },
  {
    id: 'javascript',
    label: 'JavaScript',
    fileName: 'index.js',
    monacoLanguage: 'javascript',
  },
  {
    id: 'tsx',
    label: 'TSX',
    fileName: 'index.tsx',
    monacoLanguage: 'typescript',
  },
  {
    id: 'jsx',
    label: 'JSX',
    fileName: 'index.jsx',
    monacoLanguage: 'javascript',
  },
] as const;

export type PlaygroundLanguage = (typeof LANGUAGES)[number]['id'];

export const INITIAL_SOURCES: Record<PlaygroundLanguage, string> = {
  typescript: `function greet(name: string) {
  let message = \`Hello, \${name}\`;;
  const messages = new Array(message, 'Welcome');
  return { messages: messages };
}

greet('utoo');
`,
  javascript: `function greet(name) {
  let message = \`Hello, \${name}\`;;
  const messages = new Array(message, 'Welcome');
  return { messages: messages };
}

greet('utoo');
`,
  tsx: `function Greeting({ name }: { name: string }) {
  let message = \`Hello, \${name}\`;;
  const messages = new Array(message, 'Welcome');
  const props = { messages: messages };
  return <h1>{props.messages.join(' ')}</h1>;
}

export default <Greeting name="utoo" />;
`,
  jsx: `function Greeting({ name }) {
  let message = \`Hello, \${name}\`;;
  const messages = new Array(message, 'Welcome');
  const props = { messages: messages };
  return <h1>{props.messages.join(' ')}</h1>;
}

export default <Greeting name="utoo" />;
`,
};

export const RECOMMENDED_RULES = {
  'no-array-constructor': 'error',
  'no-extra-semi': 'error',
  'object-shorthand': 'warn',
  'prefer-const': 'warn',
} satisfies Record<string, RuleConfig>;

export const INITIAL_RULES = JSON.stringify(RECOMMENDED_RULES, null, 2);

export function fileNameForLanguage(language: PlaygroundLanguage): string {
  return LANGUAGES.find((candidate) => candidate.id === language)?.fileName ?? 'index.ts';
}

export function monacoLanguageForLanguage(
  language: PlaygroundLanguage,
): 'javascript' | 'typescript' {
  return (
    LANGUAGES.find((candidate) => candidate.id === language)?.monacoLanguage ??
    'typescript'
  );
}

export function parseRules(source: string):
  | { ok: true; rules: Record<string, RuleConfig> }
  | { ok: false; message: string } {
  try {
    const value: unknown = JSON.parse(source);
    if (value === null || Array.isArray(value) || typeof value !== 'object') {
      return { ok: false, message: 'Rules must be a JSON object.' };
    }
    return { ok: true, rules: value as Record<string, RuleConfig> };
  } catch (error) {
    return {
      ok: false,
      message: error instanceof Error ? error.message : 'Invalid rules JSON.',
    };
  }
}

export function diagnosticLabel(diagnostic: LintDiagnostic): string {
  return `${diagnostic.line}:${diagnostic.column}`;
}
