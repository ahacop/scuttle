#!/usr/bin/env bash
# Records scuttle animating three test windows on workspace 5, then analyzes it.
# Usage: scripts/anim/run.sh <out dir> [scenario file] [draw delay ms]
# Takes over the screen for about 15 seconds and returns to the workspace it started on.
#
# PROFILE says what the test windows are like (default `ideal`), since a change that suits an app that does all it
# is asked at once can be wrong for one that doesn't:
#   ideal    three apps, one window each, drawn at once
#   slow     each redraw takes 25 ms, so a new size shows late and writes queue up behind it
#   grid     the first window only takes widths in steps of 120 points, as a terminal does
#   minimum  the first window refuses to be narrower than 40% of the screen
#   shared   the three windows belong to one app, which takes their frames one after another
# RESIZE is `[animations] resize`: glide (default) or instant. CONFIG_SET adds settings, as config.py takes them.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"; scenario="${2:-$here/scenario.txt}"; delay="${3:-0}"
mkdir -p "$out"
# scuttle is started by `open`, in another directory, and writes its logs here.
out="$(cd "$out" && pwd)"
bin="${ANIM_BIN:-$out/bin}"
mkdir -p "$bin"
profile="${PROFILE:-ideal}"
[[ "$profile" == slow && "$delay" == 0 ]] && delay=25
for tool in animtest animbench; do
  [[ "$bin/$tool" -nt "$here/$tool.swift" ]] || swiftc -O "$here/$tool.swift" -o "$bin/$tool"
done
# Listing devices always exits non-zero, so its status is ignored.
screen="$( (ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 || true) | sed -n 's/.*\[\([0-9]*\)\] Capture screen 0.*/\1/p' | head -1)"
seconds="$(awk '/^sleep/{s+=$2} END{print int(s+3)}' "$scenario")"

# With APP set to a scuttle.app (such as build/scuttle.app), restart scuttle from it with its animation log on.
if [[ -n "${APP:-}" ]]; then
  pkill -f "scuttle.app/Contents/MacOS/scuttle" || true
  sleep 0.8
  # Yours, with the borders and gaps the recording is read by: see config.py.
  python3 "$here/config.py" "$out/scuttle.toml" "animations.resize=${RESIZE:-glide}" ${CONFIG_SET:-}
  open --env SCUTTLE_CONFIG="$out/scuttle.toml" --env SCUTTLE_ANIM_LOG="$out/scuttle.log" --env SCUTTLE_BORDER_LOG="$out/borders.log" --env SCUTTLE_AX_LOG="$out/ax.log" --env SCUTTLE_EVENT_LOG="$out/events.log" ${APP_ENV:-} "$APP"
  for _ in $(seq 50); do scuttle version >/dev/null 2>&1 && scuttle list-workspaces >/dev/null 2>&1 && break; sleep 0.2; done
  sleep 1.5
fi
orig="$(scuttle list-workspaces --focused)"
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; scuttle workspace "$orig" >/dev/null 2>&1 || true; }
trap cleanup EXIT
scuttle workspace 5 >/dev/null; sleep 0.8
if [[ "$profile" == shared ]]; then
  "$bin/animtest" A,B,C "#d81b60,#00a651,#ff8f00" "$out/draw-{}.log" "$delay" & pids+=($!)
  sleep 2.7
else
  # pixels.py finds the windows in the recording by these colours.
  for spec in "A #d81b60" "B #00a651" "C #ff8f00"; do
    set -- $spec
    quirk=()
    [[ "$profile" == grid && "$1" == A ]] && quirk=(ANIMTEST_GRID=120)
    [[ "$profile" == minimum && "$1" == A ]] && quirk=(ANIMTEST_MIN_SHARE=0.4)
    # An empty array is unset to bash 3.2, which macOS ships.
    env ${quirk[@]+"${quirk[@]}"} "$bin/animtest" "$1" "$2" "$out/draw-$1.log" "$delay" & pids+=($!)
    sleep 0.9
  done
fi
echo "$profile ${RESIZE:-glide}" > "$out/profile.txt"
# New windows get up to a second to settle before they are tiled; wait until all three are.
for _ in $(seq 50); do
  [[ "$(scuttle list-windows --workspace 5 --format '%{app-name} %{window-layout}' | grep -c '^animtest tiling$')" == 3 ]] && break
  sleep 0.2
done
scuttle list-windows --workspace 5 --format '%{app-name} %{window-layout}'
scuttle focus left >/dev/null || true; scuttle focus left >/dev/null || true; sleep 0.8

ffmpeg -hide_banner -loglevel error -y -f avfoundation -framerate 60 -pixel_format nv12 -capture_cursor 0 -i "$screen:none" -t "$seconds" \
  -c:v libx264 -preset ultrafast -crf 20 -pix_fmt yuv420p "$out/screen.mp4" &
ff=$!
sleep 0.6
ANIMTEST="$bin/animtest" "$bin/animbench" "$out" "$scenario"
wait "$ff" || true
cleanup; trap - EXIT
python3 "$here/analyze.py" "$out"
