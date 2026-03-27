#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "error: swiftformat is not installed. Run: brew bundle --file \"$ROOT_DIR/Brewfile\"" >&2
  exit 1
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint is not installed. Run: brew bundle --file \"$ROOT_DIR/Brewfile\"" >&2
  exit 1
fi

cd "$ROOT_DIR"
swiftformat vivobody vivobodyTests vivobodyUITests --config "$ROOT_DIR/.swiftformat" --lint
swiftlint lint --strict --config "$ROOT_DIR/.swiftlint.yml"
