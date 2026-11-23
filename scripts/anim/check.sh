#!/usr/bin/env bash
# Benches this build against the last release, alternating them, and fails if this build animates clearly worse.
# Usage: scripts/anim/check.sh [runs of each, default 5]
# Takes over the screen for about 20 seconds a run (workspace 5, which must be empty); don't touch the mouse or
# keyboard meanwhile. Afterwards the scuttle that was running before is started again.
#
# HEAD_APP: the build to check. Default: build/scuttle.app, bundled here first, signed with your Developer ID so the
#   Accessibility grant carries over.
# BASE_APP: what to compare with. Default: the latest GitHub release, downloaded once into build/anim-baseline/<tag>.
# OUT: where the runs go. Default: build/anim-check/<date>.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
runs="${1:-5}"
out="${OUT:-$root/build/anim-check/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$out"

if [[ -z "${HEAD_APP:-}" ]]; then
  identity="${IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) "Developer ID Application:.*/\1/p' | head -1)}"
  (cd "$root" && IDENTITY="${identity:--}" scripts/bundle.sh >/dev/null)
  HEAD_APP="$root/build/scuttle.app"
fi
if [[ -z "${BASE_APP:-}" ]]; then
  tag="$(gh release view -R ahacop/scuttle --json tagName --jq .tagName)"
  base_dir="$root/build/anim-baseline/$tag"
  if [[ ! -d "$base_dir/scuttle.app" ]]; then
    rm -rf "$base_dir"; mkdir -p "$base_dir"
    gh release download "$tag" -R ahacop/scuttle --pattern scuttle.app.zip --dir "$base_dir"
    ditto -x -k "$base_dir/scuttle.app.zip" "$base_dir"
  fi
  BASE_APP="$base_dir/scuttle.app"
fi
echo "==> head $HEAD_APP"
echo "==> base $BASE_APP"

# The scuttle running now, started again at the end however this exits.
running="$(ps -axo command= | sed -n 's|^\(/.*scuttle\.app\)/Contents/MacOS/scuttle$|\1|p' | head -1)"
restore() {
  pkill -f "scuttle.app/Contents/MacOS/scuttle" || true
  sleep 0.8
  [[ -n "$running" ]] && open "$running"
}
trap restore EXIT

export ANIM_BIN="$out/bin"
# Alternating, so whatever else the Mac does in the meantime falls on both builds alike.
for i in $(seq "$runs"); do
  for side in base head; do
    app="$BASE_APP"; [[ $side == head ]] && app="$HEAD_APP"
    echo "==> run $i of $runs: $side"
    APP="$app" "$here/run.sh" "$out/$side$i" >"$out/log-$side$i.txt" 2>&1 || { cat "$out/log-$side$i.txt"; exit 1; }
    sleep 1
  done
done
python3 "$here/check.py" --base "$out"/base[0-9]* --head "$out"/head[0-9]*
