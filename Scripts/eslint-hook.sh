#!/usr/bin/env bash
#
#  eslint-hook.sh
#  vivobody
#
#  Pre-commit hook entry point for the website's ESLint naming conventions.
#  Runs the website's locally installed ESLint over the site sources using
#  the checked-in website/eslint.config.mjs. When the website dependencies
#  are not installed the hook warns and passes, mirroring
#  Scripts/swiftformat-hook.sh.
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESLINT="$ROOT/website/node_modules/.bin/eslint"

if [[ ! -x "$ESLINT" ]]; then
  echo "warning: website dependencies not installed; skipping website lint hook (cd website && npm install)" >&2
  exit 0
fi

cd "$ROOT/website"
exec "$ESLINT" .
