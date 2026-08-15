#!/usr/bin/env bash
#
#  knip-hook.sh
#  vivobody
#
#  Pre-commit hook entry point for the website's dead-code detection. Runs the
#  website's locally installed knip over the site sources using the checked-in
#  website/knip.json. When the website dependencies are not installed the hook
#  warns and passes, mirroring Scripts/eslint-hook.sh and swiftformat-hook.sh.
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KNIP="$ROOT/website/node_modules/.bin/knip"

if [[ ! -x "$KNIP" ]]; then
  echo "warning: website dependencies not installed; skipping dead-code hook (cd website && npm install)" >&2
  exit 0
fi

cd "$ROOT/website"
exec "$KNIP"
