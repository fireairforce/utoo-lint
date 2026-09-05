const paths = {
  code: 'm8 5-6 7 6 7m8-14 6 7-6 7m-3-16-2 18',
  config:
    'M8 3H5a2 2 0 0 0-2 2v3m13-5h3a2 2 0 0 1 2 2v3M3 16v3a2 2 0 0 0 2 2h3m8 0h3a2 2 0 0 0 2-2v-3M9 8l-3 4 3 4m6-8 3 4-3 4',
  tree: 'M12 8v5M5 17v-4h14v4M9 3h6v5H9zM2 17h6v4H2zm14 0h6v4h-6z',
  fix: 'm15 4 5 5M4 20l-1-1 12-12 2 2L5 21zm2-17v4M4 5h4m11 9v6m-3-3h6',
  link: 'm10 13 4-4m-6 6-1 1a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0m2 2 1-1a4 4 0 0 1 6 6l-4 4a4 4 0 0 1-6 0',
  check: 'm5 12 4 4L19 6',
  error: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm-3 6 6 6m0-6-6 6',
  warning: 'm12 3 10 18H2L12 3zm0 6v5m0 3v.1',
} as const;

export function Icon({ name }: { name: keyof typeof paths }) {
  return (
    <svg
      aria-hidden="true"
      className="ui-icon"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.7}
      viewBox="0 0 24 24"
    >
      <path d={paths[name]} />
    </svg>
  );
}
