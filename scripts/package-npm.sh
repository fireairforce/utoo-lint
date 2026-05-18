#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="$(uname -s)"
ARCH="$(uname -m)"

case "${PLATFORM}-${ARCH}" in
  Darwin-arm64)
    PACKAGE_DIR="${ROOT_DIR}/npm/utoo-lint-darwin-arm64"
    BINARY_NAME="utoo-lint"
    ;;
  *)
    echo "unsupported packaging target: ${PLATFORM}-${ARCH}" >&2
    exit 1
    ;;
esac

cd "${ROOT_DIR}"
zig build -Doptimize=ReleaseFast -j1

mkdir -p "${PACKAGE_DIR}/bin"
cp "${ROOT_DIR}/zig-out/bin/utoo-lint" "${PACKAGE_DIR}/bin/${BINARY_NAME}"
chmod 755 "${PACKAGE_DIR}/bin/${BINARY_NAME}"

echo "staged ${PACKAGE_DIR}/bin/${BINARY_NAME}"

