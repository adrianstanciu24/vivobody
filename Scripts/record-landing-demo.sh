#!/usr/bin/env bash

# Records a deterministic four-beat Vivobody demo from an iPhone 17 Pro
# simulator, then turns the captures into a web-ready, silent H.264 loop.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BAGUETTE_BIN="${BAGUETTE_BIN:-/opt/homebrew/bin/baguette}"
FFMPEG_BIN="${FFMPEG_BIN:-/opt/homebrew/bin/ffmpeg}"
FFPROBE_BIN="${FFPROBE_BIN:-/opt/homebrew/bin/ffprobe}"
BUNDLE_ID="astanciu.vivobody.app"
CAPTURE_DIR="$ROOT_DIR/.verify/landing-video"
RAW_DIR="$CAPTURE_DIR/raw"
WEBSITE_DIR="$ROOT_DIR/../vivobody.web"
OUTPUT_DIR="$WEBSITE_DIR/public/video"
OUTPUT_VIDEO="$OUTPUT_DIR/vivobody-demo.mp4"
OUTPUT_POSTER="$OUTPUT_DIR/vivobody-demo-poster.jpg"
LOGICAL_WIDTH=402
LOGICAL_HEIGHT=874
RECORDING_PID=""

for required_binary in "$BAGUETTE_BIN" "$FFMPEG_BIN" "$FFPROBE_BIN" jq xcrun; do
  if ! command -v "$required_binary" >/dev/null 2>&1; then
    echo "Missing required tool: $required_binary" >&2
    exit 1
  fi
done

if [[ ! -d "$WEBSITE_DIR/.git" ]]; then
  echo "Expected the standalone website repo at $WEBSITE_DIR (sibling of this repo)." >&2
  echo "Clone vivobody.web there before recording the landing demo." >&2
  exit 1
fi

if [[ -n "${SIMULATOR_UDID:-}" ]]; then
  UDID="$SIMULATOR_UDID"
else
  UDID="$($BAGUETTE_BIN list --json | jq -r '.running[] | select(.name == "iPhone 17 Pro") | .udid' | head -n 1)"
  if [[ -z "$UDID" ]]; then
    UDID="$($BAGUETTE_BIN list --json | jq -r '.running[0].udid // empty')"
  fi
fi

if [[ -z "$UDID" ]]; then
  echo "Boot an iPhone 17 Pro simulator first (Scripts/verify.sh will do this)." >&2
  exit 1
fi

if ! xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" app >/dev/null 2>&1; then
  echo "Vivobody is not installed on the booted simulator. Run Scripts/verify.sh first." >&2
  exit 1
fi

mkdir -p "$RAW_DIR" "$OUTPUT_DIR"

stop_recording() {
  if [[ -n "$RECORDING_PID" ]] && kill -0 "$RECORDING_PID" >/dev/null 2>&1; then
    kill -INT "$RECORDING_PID" >/dev/null 2>&1 || true
    wait "$RECORDING_PID" >/dev/null 2>&1 || true
  fi
  RECORDING_PID=""
}

trap stop_recording EXIT INT TERM

wait_for_label() {
  local label="$1"

  for _ in $(seq 1 40); do
    if label_is_visible "$label"; then
      return 0
    fi
    sleep 0.25
  done

  echo "Timed out waiting for simulator element: $label" >&2
  exit 1
}

label_is_visible() {
  local label="$1"
  local ui_snapshot="$CAPTURE_DIR/current-ui.json"

  "$BAGUETTE_BIN" describe-ui --udid "$UDID" >"$ui_snapshot" 2>/dev/null \
    && jq -e --arg label "$label" '.. | objects | select(.label? == $label)' "$ui_snapshot" >/dev/null
}

launch_app() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" >/dev/null
}

tap() {
  "$BAGUETTE_BIN" tap \
    --udid "$UDID" \
    --x "$1" --y "$2" \
    --width "$LOGICAL_WIDTH" --height "$LOGICAL_HEIGHT" >/dev/null
}

tap_until_label() {
  local x="$1"
  local y="$2"
  local label="$3"

  if label_is_visible "$label"; then
    return 0
  fi

  for _ in $(seq 1 3); do
    tap "$x" "$y"
    for _ in $(seq 1 8); do
      if label_is_visible "$label"; then
        return 0
      fi
      sleep 0.25
    done
  done

  echo "Tap did not reveal simulator element: $label" >&2
  exit 1
}

swipe() {
  "$BAGUETTE_BIN" swipe \
    --udid "$UDID" \
    --start-x "$1" --start-y "$2" \
    --end-x "$3" --end-y "$4" \
    --width "$LOGICAL_WIDTH" --height "$LOGICAL_HEIGHT" \
    --duration "$5" >/dev/null
}

start_recording() {
  local output_path="$1"
  xcrun simctl io "$UDID" recordVideo \
    --codec=h264 --display=1 --mask=ignored --force "$output_path" \
    >"$CAPTURE_DIR/recording.log" 2>&1 &
  RECORDING_PID=$!
  sleep 0.7
}

echo "Using simulator $UDID"
xcrun simctl status_bar "$UDID" override \
  --time 9:41 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" 'settings.weightUnit' -string lb

echo "Recording START"
launch_app --ui-test-reset --seed-showcase --pro
wait_for_label "Start Workout"
sleep 0.8
start_recording "$RAW_DIR/start.mov"
sleep 0.25
swipe 285 470 130 470 1.0
sleep 0.25
tap_until_label 201 751 "Repeat Last Workout"
sleep 2.4
stop_recording

echo "Recording LOG"
launch_app --ui-test-reset --ui-test-active-partial --pro
wait_for_label "Resume Workout"
tap_until_label 201 751 "Barbell Bench Press"
tap_until_label 126 349 "Set 3"
sleep 0.5
start_recording "$RAW_DIR/log.mov"
sleep 0.15
swipe 201 440 201 456 0.7
sleep 0.2
swipe 110 540 110 556 0.7
sleep 2.4
stop_recording

echo "Recording REST"
launch_app --ui-test-reset --ui-test-active-partial --pro
wait_for_label "Resume Workout"
tap_until_label 201 751 "Barbell Bench Press"
tap_until_label 126 349 "Set 3"
sleep 0.3
tap_until_label 201 732 "Rest timer"
sleep 0.7
start_recording "$RAW_DIR/rest.mov"
sleep 4.2
stop_recording

echo "Recording SEE"
launch_app --ui-test-reset --seed-showcase --verify-tab insights --pro
wait_for_label "Insights"
sleep 0.8
start_recording "$RAW_DIR/see.mov"
sleep 0.55
swipe 201 700 201 390 1.25
sleep 2.7
stop_recording

echo "Encoding website video"
"$FFMPEG_BIN" -hide_banner -loglevel error -y \
  -i "$RAW_DIR/start.mov" \
  -i "$RAW_DIR/log.mov" \
  -i "$RAW_DIR/rest.mov" \
  -i "$RAW_DIR/see.mov" \
  -filter_complex \
    "[0:v]trim=start=0.45:duration=4.2,setpts=PTS-STARTPTS,fps=30,scale=720:1566:flags=lanczos,setsar=1,format=yuv420p[v0]; \
     [1:v]trim=start=0.35:duration=4.2,setpts=PTS-STARTPTS,fps=30,scale=720:1566:flags=lanczos,setsar=1,format=yuv420p[v1]; \
     [2:v]trim=start=0.3:duration=4.2,setpts=PTS-STARTPTS,fps=30,scale=720:1566:flags=lanczos,setsar=1,format=yuv420p[v2]; \
     [3:v]trim=start=0.4:duration=4.2,setpts=PTS-STARTPTS,fps=30,scale=720:1566:flags=lanczos,setsar=1,format=yuv420p[v3]; \
     [v0][v1][v2][v3]concat=n=4:v=1:a=0[v]" \
  -map "[v]" \
  -an \
  -c:v libx264 -preset slow -crf 23 \
  -movflags +faststart \
  "$OUTPUT_VIDEO"

"$FFMPEG_BIN" -hide_banner -loglevel error -y \
  -ss 0.2 -i "$OUTPUT_VIDEO" \
  -frames:v 1 -q:v 2 \
  "$OUTPUT_POSTER"

echo
"$FFPROBE_BIN" -v error \
  -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$OUTPUT_VIDEO"
echo "Wrote $OUTPUT_VIDEO"
echo "Wrote $OUTPUT_POSTER"
