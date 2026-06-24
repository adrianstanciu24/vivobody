#!/usr/bin/env bash
# verify.sh — build vivobody, boot a headless simulator, launch the app,
# capture a screenshot + accessibility tree at the launch state (or after
# tapping into a specific tab). Output lands in .verify/.
#
# Usage:
#   Scripts/verify.sh                # default: iPhone 17 Pro, iOS 26.4, launch state
#   TAB=library Scripts/verify.sh    # tap a tab first (today | history | library | insights | me)
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
DERIVED="$ROOT/build"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
OUT_DIR="$ROOT/.verify"
TAB="${TAB:-}"

mkdir -p "$OUT_DIR"

if ! command -v baguette >/dev/null 2>&1; then
  echo "error: baguette CLI not found. Install via: brew install baguette" >&2
  exit 1
fi

echo "▸ Building $SCHEME (destination: $SIMULATOR_NAME, iOS $SIMULATOR_OS)..."
xcodebuild \
  -project vivobody.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}" \
  -derivedDataPath "$DERIVED" \
  build 2>&1 \
  | grep -E "(warning:|error:|BUILD SUCCEEDED|BUILD FAILED)" \
  | grep -v "AppIntents.framework dependency" || true

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: build artifact not found at $APP_PATH" >&2
  exit 1
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
sleep 1

echo "▸ Reinstalling + launching $BUNDLE_ID..."
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"
# LAUNCH_ARGS lets a caller seed data, e.g. LAUNCH_ARGS='--seed-history'.
xcrun simctl launch "$UDID" "$BUNDLE_ID" ${LAUNCH_ARGS:-} >/dev/null
sleep 3

# Optional tab tap. Coordinates calibrated for iPhone 17 Pro (402x874 points).
# Adjust if you switch device sizes.
if [[ -n "$TAB" ]]; then
  case "$TAB" in
    today)    X=53  ;;
    history)  X=128 ;;
    library)  X=202 ;;
    insights) X=276 ;;
    me)       X=350 ;;
    *) echo "error: unknown TAB '$TAB' (today | history | library | insights | me)" >&2; exit 1 ;;
  esac
  Y=825
  echo "▸ Tapping $TAB tab at ($X, $Y)..."
  baguette tap --udid "$UDID" --x $X --y $Y --width 402 --height 874 >/dev/null 2>&1
  sleep 1
  STEM="$OUT_DIR/$TAB"
else
  STEM="$OUT_DIR/launch"
fi

echo "▸ Capturing screenshot + UI tree..."
baguette screenshot --udid "$UDID" --output "${STEM}.jpg" >/dev/null 2>&1
baguette describe-ui --udid "$UDID" --output "${STEM}-ui.json" >/dev/null 2>&1

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
