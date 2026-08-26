#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PATH="${ROOT_DIR}/zig-out/bin/utoo-lint.wasm"
PACKAGE_PATH="${ROOT_DIR}/npm/@utoo/lint-wasm/utoo-lint.wasm"

cd "${ROOT_DIR}"
zig build wasm

test -s "${SOURCE_PATH}"
MAGIC="$(od -An -tx1 -N4 "${SOURCE_PATH}" | tr -d ' \n')"
if [[ "${MAGIC}" != "0061736d" ]]; then
  echo "invalid WebAssembly artifact: ${SOURCE_PATH}" >&2
  exit 1
fi

cp "${SOURCE_PATH}" "${PACKAGE_PATH}"
chmod 0644 "${PACKAGE_PATH}"
test -s "${PACKAGE_PATH}"

node --input-type=module -e '
  import { readFile } from "node:fs/promises";

  const bytes = await readFile(process.argv[1]);
  const module = await WebAssembly.compile(bytes);
  const imports = WebAssembly.Module.imports(module);
  if (imports.length !== 0) {
    throw new Error(`expected a freestanding module, found imports: ${JSON.stringify(imports)}`);
  }

  const exportedNames = new Set(WebAssembly.Module.exports(module).map(({ name }) => name));
  for (const name of ["memory", "alloc", "free", "lint", "abi_version"]) {
    if (!exportedNames.has(name)) throw new Error(`missing WebAssembly export: ${name}`);
  }

  const instance = await WebAssembly.instantiate(module, {});
  if (instance.exports.abi_version() !== 1) {
    throw new Error(`unsupported WebAssembly ABI: ${instance.exports.abi_version()}`);
  }
' "${PACKAGE_PATH}"

echo "staged ${PACKAGE_PATH}"
