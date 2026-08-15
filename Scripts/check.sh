#!/usr/bin/env bash
#
#  check.sh
#  vivobody
#
#  Canonical non-UI validation entry point. It proves the architecture
#  guardrails themselves, checks repository boundaries and generated catalog
#  parity, then compiles the complete app and widget graph for the simulator.
#  Full build output lands in .verify/check-build.log; the terminal stays
#  focused on actionable diagnostics.
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_DIR="$ROOT/.verify"
BUILD_LOG="$OUT_DIR/check-build.log"
DIAGNOSTICS_LOG="$OUT_DIR/check-build-diagnostics.log"
mkdir -p "$OUT_DIR"

echo "▸ Testing architecture guardrails..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_check_architecture.py'

echo "▸ Testing documentation guardrails..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_check_documentation.py'

echo "▸ Testing semantic scenario harness..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_verify_scenario.py'

echo "▸ Testing source-size ratchet..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_check_source_sizes.py'

echo "▸ Testing naming-convention guardrails..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_check_naming.py'

echo "▸ Testing complexity guardrails..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_check_complexity.py'

echo "▸ Testing manual quality scan..."
/usr/bin/python3 -m unittest discover \
  -s Scripts/tests \
  -p 'test_quality_scan.py'

echo "▸ Testing VivoKit snapshot contracts..."
swift test --package-path VivoKit

echo "▸ Checking persistence baseline integrity..."
(cd vivobodyTests/Fixtures && shasum -a 256 -c SHA256SUMS)

echo "▸ Checking repository architecture..."
/usr/bin/python3 Scripts/check_architecture.py

echo "▸ Checking source-size ratchet..."
/usr/bin/python3 Scripts/check_source_sizes.py

echo "▸ Checking Swift naming conventions..."
/usr/bin/python3 Scripts/check_naming.py

echo "▸ Checking cyclomatic complexity..."
/usr/bin/python3 Scripts/check_complexity.py

echo "▸ Checking Swift formatting..."
if command -v swiftformat >/dev/null 2>&1; then
    if ! swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/ \
        2>&1 | tail -1 | grep -q "^0/"; then
        echo "error: SwiftFormat found formatting issues; run 'swiftformat vivobody/ vivobodyWidgets/ VivoKit/Sources/' to fix" >&2
        exit 1
    fi
else
    echo "warning: swiftformat not installed; skipping Swift formatting check (brew install swiftformat)" >&2
fi

echo "▸ Checking website dead code..."
KNIP="$ROOT/website/node_modules/.bin/knip"
if [[ -x "$KNIP" ]]; then
    if ! (cd "$ROOT/website" && "$KNIP"); then
        echo "error: knip found unused files, exports, or dependencies; run 'cd website && npm run lint:dead' for details" >&2
        exit 1
    fi
else
    echo "warning: website dependencies not installed; skipping dead-code check (cd website && npm install)" >&2
fi

echo "▸ Checking repository knowledge map..."
/usr/bin/python3 Scripts/check_documentation.py

echo "▸ Checking generated exercise catalog..."
/usr/bin/python3 Scripts/catalog.py --check

echo "▸ Building vivobody..."
if ! xcodebuild \
  -scheme vivobody \
  -destination 'generic/platform=iOS Simulator' \
  build >"$BUILD_LOG" 2>&1; then
  grep -E '(warning:|error:|BUILD SUCCEEDED|BUILD FAILED)' "$BUILD_LOG" \
    | grep -v 'AppIntents.framework dependency' || tail -n 80 "$BUILD_LOG"
  echo "error: xcodebuild failed; full log at $BUILD_LOG" >&2
  exit 1
fi

grep -E '(warning:|error:)' "$BUILD_LOG" \
  | grep -v 'AppIntents.framework dependency' >"$DIAGNOSTICS_LOG" || true
if [[ -s "$DIAGNOSTICS_LOG" ]]; then
  cat "$DIAGNOSTICS_LOG" >&2
  echo "error: build completed with unexpected warnings; full log at $BUILD_LOG" >&2
  exit 1
fi

echo "▸ Vivobody checks passed. Build log: $BUILD_LOG"
