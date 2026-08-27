import { useState } from 'react';

const OPEN_DEPTH = 3;
const MAX_BRANCH_CHILDREN = 1_000;
const MAX_TREE_DEPTH = 96;
const MAX_STRING_LENGTH = 240;

interface ASTTreeProps {
  onSelect(start: number, end: number): void;
  program: unknown;
}

interface ASTValueProps {
  depth: number;
  name: string | null;
  onSelect(start: number, end: number): void;
  path: string;
  value: unknown;
}

interface ASTNodeRecord extends Record<string, unknown> {
  end?: number;
  start?: number;
  type: string;
}

function isBranch(value: unknown): value is unknown[] | Record<string, unknown> {
  return (
    value !== null &&
    typeof value === 'object' &&
    !(value instanceof RegExp)
  );
}

function isASTNode(value: unknown): value is ASTNodeRecord {
  return (
    isBranch(value) &&
    !Array.isArray(value) &&
    typeof value.type === 'string'
  );
}

function ASTLeaf({ name, value }: Pick<ASTValueProps, 'name' | 'value'>) {
  let className = 'ast-null';
  let text = 'null';

  if (typeof value === 'string') {
    className = 'ast-str';
    const clipped =
      value.length > MAX_STRING_LENGTH
        ? `${value.slice(0, MAX_STRING_LENGTH)}…`
        : value;
    text = JSON.stringify(clipped);
  } else if (typeof value === 'number' || typeof value === 'bigint') {
    className = 'ast-num';
    text = typeof value === 'bigint' ? `${value}n` : String(value);
  } else if (typeof value === 'boolean') {
    className = 'ast-bool';
    text = String(value);
  } else if (value instanceof RegExp) {
    className = 'ast-str';
    text = String(value);
  } else if (value === undefined) {
    className = 'ast-null';
    text = 'undefined';
  }

  return (
    <div className="ast-row">
      {name !== null && <span className="ast-key">{name}: </span>}
      <span className={className}>{text}</span>
    </div>
  );
}

function ASTEmpty({ name, text }: { name: string | null; text: string }) {
  return (
    <div className="ast-row">
      {name !== null && <span className="ast-key">{name}: </span>}
      <span className="ast-meta">{text}</span>
    </div>
  );
}

function ASTBranch({
  depth,
  name,
  onSelect,
  path,
  value,
}: ASTValueProps & { value: unknown[] | Record<string, unknown> }) {
  const [open, setOpen] = useState(depth < OPEN_DEPTH);
  const node = isASTNode(value) ? value : undefined;
  const entries = Array.isArray(value)
    ? value.map((item, index) => [String(index), item] as const)
    : Object.entries(value).filter(
        ([key]) => !node || !['type', 'start', 'end'].includes(key),
      );
  const visibleEntries = entries.slice(0, MAX_BRANCH_CHILDREN);

  const selectNode = () => {
    if (
      node &&
      typeof node.start === 'number' &&
      typeof node.end === 'number'
    ) {
      onSelect(node.start, node.end);
    }
  };

  return (
    <details
      className="ast-branch"
      onToggle={(event) => setOpen(event.currentTarget.open)}
      open={open}
    >
      <summary onClick={selectNode}>
        {name !== null && <span className="ast-key">{name}: </span>}
        {Array.isArray(value) && (
          <span className="ast-meta">[{value.length}]</span>
        )}
        {node && (
          <>
            <span className="ast-type">{node.type}</span>
            {typeof node.start === 'number' && typeof node.end === 'number' && (
              <span className="ast-span">
                {' '}
                {node.start}:{node.end}
              </span>
            )}
          </>
        )}
        {!Array.isArray(value) && !node && (
          <span className="ast-meta">{'{}'}</span>
        )}
      </summary>

      {open && (
        <div className="ast-body">
          {depth >= MAX_TREE_DEPTH ? (
            <div className="ast-row ast-limit">Maximum tree depth reached</div>
          ) : (
            visibleEntries.map(([key, child]) => (
              <ASTValue
                depth={depth + 1}
                key={`${path}/${key}`}
                name={key}
                onSelect={onSelect}
                path={`${path}/${key}`}
                value={child}
              />
            ))
          )}
          {entries.length > visibleEntries.length && (
            <div className="ast-row ast-limit">
              {entries.length - visibleEntries.length} more entries
            </div>
          )}
        </div>
      )}
    </details>
  );
}

function ASTValue(props: ASTValueProps) {
  if (isBranch(props.value)) {
    if (Array.isArray(props.value) && props.value.length === 0) {
      return <ASTEmpty name={props.name} text="[]" />;
    }
    if (!Array.isArray(props.value) && Object.keys(props.value).length === 0) {
      return <ASTEmpty name={props.name} text="{}" />;
    }
    return <ASTBranch {...props} value={props.value} />;
  }

  return <ASTLeaf name={props.name} value={props.value} />;
}

export function ASTTree({ onSelect, program }: ASTTreeProps) {
  return (
    <div className="ast-tree">
      <ASTValue
        depth={0}
        name={null}
        onSelect={onSelect}
        path="ast"
        value={program}
      />
    </div>
  );
}
