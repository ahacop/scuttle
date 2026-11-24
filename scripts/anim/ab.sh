#!/usr/bin/env bash
# Records several builds or settings in turn (A, B, A, B, ...) and prints each one's measures across its runs.
# Usage: scripts/anim/ab.sh <out dir> <runs of each> <name>=<scuttle.app>[::<open flags>]...
#   scripts/anim/ab.sh /tmp/ab 3 base=build/ab/base/scuttle.app head=build/scuttle.app \
#     "untracked=build/scuttle.app::--env SCUTTLE_NO_BORDER_TRACKING=1"
# CONDITIONS lists what to record them under, as `<profile>:<resize>` (run.sh's PROFILE and RESIZE), default
# `ideal:glide`. A change is only better if it is no worse under any of them:
#   CONDITIONS="ideal:glide ideal:instant slow:glide shared:glide grid:glide minimum:glide" scripts/anim/ab.sh ...
# Takes over the screen for about 25 seconds a run (workspace 5, which must be empty); don't touch the mouse or
# keyboard meanwhile. Afterwards the scuttle that was running before is started again.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/awake.sh"
out="$1"; runs="$2"; shift 2
mkdir -p "$out"
conditions="${CONDITIONS:-ideal:glide}"

running="$(ps -axo command= | sed -n 's|^\(/.*scuttle\.app\)/Contents/MacOS/scuttle$|\1|p' | head -1)"
restore() {
  pkill -f "scuttle.app/Contents/MacOS/scuttle" || true
  sleep 0.8
  [[ -n "$running" ]] && open "$running"
}
trap restore EXIT

export ANIM_BIN="$out/bin"
for i in $(seq "$runs"); do
  for condition in $conditions; do
    for variant in "$@"; do
      name="${variant%%=*}"; rest="${variant#*=}"
      app="${rest%%::*}"; flags=""; [[ "$rest" == *::* ]] && flags="${rest#*::}"
      dir="$out/$name-${condition/:/-}-$i"
      echo "==> run $i of $runs: $name, $condition"
      APP="$(cd "$app" && pwd)" APP_ENV="$flags" PROFILE="${condition%%:*}" RESIZE="${condition#*:}" \
        "$here/run.sh" "$dir" >"$out/log-${dir##*/}.txt" 2>&1 || { cat "$out/log-${dir##*/}.txt"; exit 1; }
      sleep 1
    done
  done
done
for condition in $conditions; do
  for variant in "$@"; do
    name="${variant%%=*}"
    echo "== $name, $condition"
    python3 "$here/compare.py" "$out/$name-${condition/:/-}"-[0-9]*
  done
done
