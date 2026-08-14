#!/usr/bin/env bash
#
#  swiftformat-hook.sh
#  vivobody
#
#  Pre-commit hook entry point for SwiftFormat. Formats the staged Swift
#  files passed by the hook framework in place using the checked-in
#  .swiftformat configuration; the framework then fails the hook so the
#  reformatted files can be re-staged. When SwiftFormat is not installed the
#  hook warns and passes, mirroring Scripts/check.sh.
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -eq 0 ]]; then
  exit 0
fi

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "warning: swiftformat not installed; skipping Swift formatting hook (brew install swiftformat)" >&2
  exit 0
fi

exec swiftformat --config "$ROOT/.swiftformat" "$@"
