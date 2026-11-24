#!/usr/bin/env bash
# Records animcal's glides, whose smoothness is known, to tell what the recording itself adds and what moving a
# window through Accessibility costs with no scuttle involved. Usage: scripts/anim/cal.sh <out dir> [kind...]
# A kind is `layer`, `window[:delay ms]`, or `ax[:delay ms[:move|size|both[:draw delay ms]]]`; default
# `layer window ax`. scuttle is stopped meanwhile, so nothing tiles the test window, and started again afterwards.
# Takes over the screen for about ten seconds a kind.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/awake.sh"
out="$1"; shift
mkdir -p "$out"; out="$(cd "$out" && pwd)"
kinds=("$@"); [[ ${#kinds[@]} -gt 0 ]] || kinds=(layer window ax)
bin="${ANIM_BIN:-$out/bin}"; mkdir -p "$bin"
[[ "$bin/animcal" -nt "$here/animcal.swift" ]] || swiftc -O "$here/animcal.swift" -o "$bin/animcal"
screen="$( (ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 || true) | sed -n 's/.*\[\([0-9]*\)\] Capture screen 0.*/\1/p' | head -1)"

running="$(ps -axo command= | sed -n 's|^\(/.*scuttle\.app\)/Contents/MacOS/scuttle$|\1|p' | head -1)"
target=""
restore() {
  [[ -n "$target" ]] && kill "$target" 2>/dev/null || true
  [[ -n "$running" ]] && open "$running"
}
trap restore EXIT
pkill -f "scuttle.app/Contents/MacOS/scuttle" || true
sleep 1

dirs=()
for kind in "${kinds[@]}"; do
  IFS=: read -r mode delay what draw <<<"$kind"
  dir="$out/${kind//:/-}"; mkdir -p "$dir"; dirs+=("$dir")
  rm -f "$dir/pixels.json"
  swift -e 'import AppKit; let f = NSScreen.main!.frame; print("{\"width\": \(f.width), \"height\": \(f.height), \"scale\": \(NSScreen.main!.backingScaleFactor)}")' > "$dir/screen.json"
  target=""
  if [[ "$mode" == ax ]]; then
    ANIMCAL_DRAW_MS="${draw:-0}" "$bin/animcal" target & target=$!
    sleep 2.5
  fi
  ffmpeg -hide_banner -loglevel error -y -f avfoundation -framerate 60 -pixel_format nv12 -capture_cursor 0 -i "$screen:none" -t 9 \
    -c:v libx264 -preset ultrafast -crf 20 -pix_fmt yuv420p "$dir/screen.mp4" &
  ff=$!
  sleep 0.8
  case "$mode" in
    layer) "$bin/animcal" layer ;;
    window) "$bin/animcal" window "${delay:-0}" ;;
    ax) "$bin/animcal" ax "$target" "${delay:-0}" "${what:-move}" ;;
  esac
  wait "$ff" || true
  [[ -n "$target" ]] && kill "$target" 2>/dev/null || true
  target=""
  sleep 0.5
done
python3 "$here/cal.py" "${dirs[@]}"
