let globalIgnoreCount = 0;

export function defineConfig(...args) {
  if (args.length === 0) {
    throw new TypeError("Expected one or more arguments.");
  }
  return flattenConfigArgs(args);
}

export function globalIgnores(ignorePatterns, name) {
  if (!Array.isArray(ignorePatterns)) {
    throw new TypeError("ignorePatterns must be an array");
  }
  if (ignorePatterns.length === 0) {
    throw new TypeError("ignorePatterns must contain at least one pattern");
  }
  const id = globalIgnoreCount++;
  return {
    name: name || `globalIgnores ${id}`,
    ignores: ignorePatterns
  };
}

function flattenConfigArgs(values) {
  const configs = [];
  for (const value of values) {
    if (Array.isArray(value)) {
      configs.push(...flattenConfigArgs(value));
    } else if (typeof value === "object" && value !== null) {
      configs.push(value);
    } else {
      throw new TypeError(`Expected an object but received ${String(value)}.`);
    }
  }
  return configs;
}
