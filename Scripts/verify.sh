#!/usr/bin/env bash
# verify.sh — incrementally build vivobody, reuse a headless simulator, launch
# a deterministic app state, then capture a screenshot + accessibility tree.
# Output lands in .verify/.
#
# Usage:
#   Scripts/verify.sh                # build, launch, and capture Today
#   TAB=library Scripts/verify.sh    # launch directly into a tab
#   CAPTURE_ONLY=1 Scripts/verify.sh # capture the currently running app without rebuilding
#   CLEAN_BUILD=1 Scripts/verify.sh  # discard the build cache before building
#   RESET_STATE=0 Scripts/verify.sh  # preserve the simulator's app data
#   SIMULATOR_NAME='iPhone 16e' Scripts/verify.sh
#   SIMULATOR_OS=26.2 Scripts/verify.sh
#
# Requires: baguette (brew install baguette), Xcode 17+ with iOS 26.x simulators.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_OS="${SIMULATOR_OS:-26.5}"
SCHEME="vivobody"
BUNDLE_ID="astanciu.vivobody.app"
OUT_DIR="$ROOT/.verify"
DERIVED="$OUT_DIR/DerivedData"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
BUILD_LOG="$OUT_DIR/build.log"
TAB="${TAB:-}"
CAPTURE_ONLY="${CAPTURE_ONLY:-0}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"
RESET_STATE="${RESET_STATE:-1}"
READY_TIMEOUT="${READY_TIMEOUT:-15}"

case "$TAB" in
  "")       EXPECTED_LABEL="Tab Bar" ;;
  today)    EXPECTED_LABEL="Today"   ;;
  history)  EXPECTED_LABEL="History" ;;
  library)  EXPECTED_LABEL="Library" ;;
  insights) EXPECTED_LABEL="Insights";;
  me)       EXPECTED_LABEL="Me"      ;;
  *) echo "error: unknown TAB '$TAB' (today | history | library | insights | me)" >&2; exit 1 ;;
esac

mkdir -p "$OUT_DIR"

if ! command -v baguette >/dev/null 2>&1; then
  echo "error: baguette CLI not found. Install via: brew install baguette" >&2
  exit 1
fi

if [[ "$CAPTURE_ONLY" != "1" ]]; then
  if [[ "$CLEAN_BUILD" == "1" ]]; then
    echo "▸ Removing cached build products..."
    rm -rf "$DERIVED"
  fi

  echo "▸ Incrementally building $SCHEME (destination: $SIMULATOR_NAME, iOS $SIMULATOR_OS)..."
  if ! xcodebuild \
    -project vivobody.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}" \
    -derivedDataPath "$DERIVED" \
    build >"$BUILD_LOG" 2>&1; then
    grep -E "(warning:|error:|BUILD SUCCEEDED|BUILD FAILED)" "$BUILD_LOG" \
      | grep -v "AppIntents.framework dependency" || true
    echo "error: xcodebuild failed; full log at $BUILD_LOG" >&2
    exit 1
  fi

  grep -E "(warning:|error:|BUILD SUCCEEDED|BUILD FAILED)" "$BUILD_LOG" \
    | grep -v "AppIntents.framework dependency" || true

  if [[ ! -d "$APP_PATH" ]]; then
    echo "error: build artifact not found at $APP_PATH" >&2
    exit 1
  fi
fi

UDID="$(baguette list 2>/dev/null | SIMULATOR_NAME="$SIMULATOR_NAME" SIMULATOR_OS="$SIMULATOR_OS" python3 -c '
import json, os, sys
name = os.environ["SIMULATOR_NAME"]
runtime = "iOS " + os.environ["SIMULATOR_OS"]
for line in sys.stdin:
    if not line.strip(): continue
    d = json.loads(line)
    if d["name"] == name and d["runtime"] == runtime:
        print(d["udid"]); break
')"

if [[ -z "$UDID" ]]; then
  echo "error: no simulator '$SIMULATOR_NAME' on iOS $SIMULATOR_OS" >&2
  exit 1
fi

echo "▸ Booting $SIMULATOR_NAME ($UDID)..."
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

if [[ "$CAPTURE_ONLY" != "1" ]]; then
  echo "▸ Installing + launching $BUNDLE_ID..."
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP_PATH"

  APP_ARGS=()
  if [[ "$RESET_STATE" == "1" ]]; then
    APP_ARGS+=(--ui-test-reset)
  fi
  if [[ -n "$TAB" ]]; then
    APP_ARGS+=(--verify-tab "$TAB")
  fi
  if [[ -n "${LAUNCH_ARGS:-}" ]]; then
    read -r -a EXTRA_ARGS <<< "$LAUNCH_ARGS"
    APP_ARGS+=("${EXTRA_ARGS[@]}")
  fi
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "${APP_ARGS[@]}" >/dev/null
else
  PROBE_TREE="$OUT_DIR/probe-ui.json"
  if ! baguette describe-ui --udid "$UDID" --output "$PROBE_TREE" >/dev/null 2>&1 \
    || ! python3 -c '
import json, sys
tree = json.load(open(sys.argv[1]))
ready = (tree.get("label") or "").lower() == "vivobody" and bool(tree.get("children"))
sys.exit(0 if ready else 1)
' "$PROBE_TREE"; then
    echo "▸ Relaunching the installed app..."
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  fi
fi

READY_TREE="$OUT_DIR/readiness-ui.json"
REQUIRED_LABEL=""
if [[ -n "$TAB" ]]; then
  REQUIRED_LABEL="$EXPECTED_LABEL"
elif [[ "$CAPTURE_ONLY" != "1" && "$RESET_STATE" == "1" ]]; then
  REQUIRED_LABEL="$EXPECTED_LABEL"
fi
DEADLINE=$((SECONDS + READY_TIMEOUT))
until baguette describe-ui --udid "$UDID" --output "$READY_TREE" >/dev/null 2>&1 \
  && python3 -c '
import json, sys
tree = json.load(open(sys.argv[1]))
required = sys.argv[2]
def contains(node):
    return node.get("label") == required or any(contains(child) for child in node.get("children", []))
ready = (tree.get("label") or "").lower() == "vivobody" and bool(tree.get("children"))
ready = ready and (not required or contains(tree))
sys.exit(0 if ready else 1)
' "$READY_TREE" "$REQUIRED_LABEL"; do
  if (( SECONDS >= DEADLINE )); then
    echo "error: app UI did not become accessible within ${READY_TIMEOUT}s" >&2
    exit 1
  fi
  sleep 0.5
done

if [[ -n "$TAB" ]]; then
  STEM="$OUT_DIR/$TAB"
else
  STEM="$OUT_DIR/launch"
fi

echo "▸ Capturing screenshot + UI tree..."
baguette screenshot --udid "$UDID" --output "${STEM}.jpg" >/dev/null
baguette describe-ui --udid "$UDID" --output "${STEM}-ui.json" >/dev/null 2>&1
if ! python3 -c '
import json, sys
tree = json.load(open(sys.argv[1]))
ready = (tree.get("label") or "").lower() == "vivobody" and bool(tree.get("children"))
sys.exit(0 if ready else 1)
' "${STEM}-ui.json"; then
  echo "error: capture does not contain the Vivobody UI" >&2
  exit 1
fi

echo ""
echo "Screenshot:   ${STEM}.jpg"
echo "UI tree:      ${STEM}-ui.json"
echo ""
echo "Visible labels (first 25):"
python3 -c "
import json
tree = json.load(open('${STEM}-ui.json'))
out = []
def walk(n):
    if n.get('label') and not n.get('hidden'):
        out.append((n.get('role',''), n['label']))
    for c in n.get('children', []):
        walk(c)
walk(tree)
for role, label in out[:25]:
    print(f'  {role:22s} | {label}')
"
