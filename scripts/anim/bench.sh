#!/usr/bin/env bash
# Records the scenario several times and prints each measure's mean and range across the runs.
# Usage: scripts/anim/bench.sh <out dir> [runs, default 3] [scenario]
# With APP set, scuttle is restarted from it (with its logs on) before the first run.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/awake.sh"
out="$1"; runs="${2:-3}"; scenario="${3:-${SCENARIO:-$here/scenario.txt}}"
mkdir -p "$out"
export ANIM_BIN="${ANIM_BIN:-$out/bin}"
for i in $(seq "$runs"); do
  # Only the first run restarts scuttle; the log of the later runs goes to the first run's directory.
  if [[ $i -gt 1 ]]; then unset APP; fi
  "$here/run.sh" "$out/run$i" "$scenario" >/dev/null 2>&1
  # A restarted scuttle logs to the first run's directory; the analysis looks for its logs in each run.
  for log in scuttle.log borders.log; do
    [[ -f "$out/run1/$log" && ! -f "$out/run$i/$log" ]] && cp "$out/run1/$log" "$out/run$i/$log"
  done
  sleep 1
done
python3 "$here/compare.py" "$out"/run*
