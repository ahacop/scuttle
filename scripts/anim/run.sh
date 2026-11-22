#!/usr/bin/env bash
# Records scuttle animating three test windows on workspace 5, then analyzes it.
# Usage: scripts/anim/run.sh <out dir> [scenario file] [draw delay ms]
# Takes over the screen for about 15 seconds and returns to the workspace it started on.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"; scenario="${2:-$here/scenario.txt}"; delay="${3:-0}"
bin="${ANIM_BIN:-$out/bin}"
mkdir -p "$out" "$bin"
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
  open --env SCUTTLE_ANIM_LOG="$out/scuttle.log" --env SCUTTLE_BORDER_LOG="$out/borders.log" --env SCUTTLE_AX_LOG="$out/ax.log" "$APP"
  for _ in $(seq 50); do scuttle version >/dev/null 2>&1 && scuttle list-workspaces >/dev/null 2>&1 && break; sleep 0.2; done
  sleep 1.5
fi
orig="$(scuttle list-workspaces --focused)"
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; scuttle workspace "$orig" >/dev/null 2>&1 || true; }
trap cleanup EXIT
scuttle workspace 5 >/dev/null; sleep 0.8
for spec in "A #b03a2e" "B #1f618d" "C #1e8449"; do
  set -- $spec
  "$bin/animtest" "$1" "$2" "$out/draw-$1.log" "$delay" & pids+=($!)
  sleep 0.9
done
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
"$bin/animbench" "$out" "$scenario"
wait "$ff" || true
cleanup; trap - EXIT
python3 "$here/analyze.py" "$out"
