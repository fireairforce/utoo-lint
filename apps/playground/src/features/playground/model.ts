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
export type PlaygroundRulesMode = 'recommended' | 'custom';

export interface PlaygroundSharePayload {
  language: PlaygroundLanguage;
  rulesMode: PlaygroundRulesMode;
  rulesSource: string;
  source: string;
  version: 1;
}

const SHARE_HASH_KEY = 'playground';
const SHARE_PAYLOAD_VERSION = 1;
const MAX_ENCODED_SHARE_LENGTH = 512_000;
const MAX_SHARED_RULES_LENGTH = 50_000;
const MAX_SHARED_SOURCE_LENGTH = 250_000;

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

function encodeBase64Url(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = '';

  for (let index = 0; index < bytes.length; index += 32_768) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 32_768));
  }

  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/u, '');
}

function decodeBase64Url(value: string): string {
  const base64 = value.replaceAll('-', '+').replaceAll('_', '/');
  const padding = '='.repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(`${base64}${padding}`);
  const bytes = Uint8Array.from(binary, (character) =>
    character.charCodeAt(0),
  );
  return new TextDecoder().decode(bytes);
}

function isPlaygroundLanguage(value: unknown): value is PlaygroundLanguage {
  return LANGUAGES.some((language) => language.id === value);
}

function isPlaygroundSharePayload(
  value: unknown,
): value is PlaygroundSharePayload {
  if (value === null || typeof value !== 'object') return false;

  const payload = value as Partial<PlaygroundSharePayload>;
  return (
    payload.version === SHARE_PAYLOAD_VERSION &&
    isPlaygroundLanguage(payload.language) &&
    (payload.rulesMode === 'recommended' || payload.rulesMode === 'custom') &&
    typeof payload.rulesSource === 'string' &&
    payload.rulesSource.length <= MAX_SHARED_RULES_LENGTH &&
    typeof payload.source === 'string' &&
    payload.source.length <= MAX_SHARED_SOURCE_LENGTH
  );
}

export function createPlaygroundShareUrl(
  currentUrl: string,
  payload: PlaygroundSharePayload,
): string {
  if (!isPlaygroundSharePayload(payload)) {
    throw new RangeError('Playground content is too large to share in a URL.');
  }

  const url = new URL(currentUrl);
  const encoded = encodeBase64Url(JSON.stringify(payload));
  url.hash = `${SHARE_HASH_KEY}=${encoded}`;
  return url.toString();
}

export function parsePlaygroundShareUrl(
  currentUrl: string,
): PlaygroundSharePayload | undefined {
  try {
    const url = new URL(currentUrl);
    const encoded = new URLSearchParams(url.hash.slice(1)).get(SHARE_HASH_KEY);
    if (!encoded || encoded.length > MAX_ENCODED_SHARE_LENGTH) return undefined;

    const payload: unknown = JSON.parse(decodeBase64Url(encoded));
    return isPlaygroundSharePayload(payload) ? payload : undefined;
  } catch {
    return undefined;
  }
}

export function removePlaygroundShareState(currentUrl: string): string {
  const url = new URL(currentUrl);
  const parameters = new URLSearchParams(url.hash.slice(1));
  if (!parameters.has(SHARE_HASH_KEY)) return currentUrl;

  parameters.delete(SHARE_HASH_KEY);
  url.hash = parameters.toString();
  return url.toString();
}

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
