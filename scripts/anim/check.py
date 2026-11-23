#!/usr/bin/env python3
"""Compares runs of two builds and fails if the head build animates clearly worse than the base build.

Each measure is the median over each build's runs of analyze.py's summary. A measure fails when the head's is worse
than the base's by more than both a share of the base and a fixed amount: runs vary by more than either alone on a
busy Mac, and a measure near zero (torn frames) would otherwise fail on one frame.

Usage: check.py --base <run dir>... --head <run dir>... [--json]
"""
import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import analyze, summary  # noqa: E402

# measure: (higher is better, share of the base, fixed amount, format). With no share, a measure is only shown:
# bfar counts frames off by more than 4 points, so a border trailing by 5 points on every frame scores worse than
# one standing still and then jumping 300; the mean `border` is the one to hold.
LIMITS = {
    "torn": (False, 0.5, 3, "{:.0f}"),
    "stalls": (False, 0.25, 15, "{:.0f}"),
    "reversals": (False, 0.5, 2, "{:.0f}"),
    "hz": (True, 0.1, 3, "{:.1f}"),
    "ms": (False, 0.15, 25, "{:.0f}"),
    "stale": (False, 0.25, 0.05, "{:.0%}"),
    "border": (False, 0.25, 8, "{:.1f}"),
    "bfar": (False, None, None, "{:.0%}"),
}


def medians(runs):
    summaries = [summary(analyze(Path(r))) for r in runs]
    return {k: statistics.median(s[k] for s in summaries) for k in LIMITS}


def check(base, head):
    """Each measure's base and head medians, how far worse the head may be, and whether it is."""
    rows = []
    for k, (higher, share, fixed, fmt) in LIMITS.items():
        allowed = None if share is None else max(abs(base[k]) * share, fixed)
        worse = base[k] - head[k] if higher else head[k] - base[k]
        rows.append(dict(measure=k, base=base[k], head=head[k], allowed=allowed,
                         failed=allowed is not None and worse > allowed, fmt=fmt))
    return rows


def split(argv):
    groups, current = {"--base": [], "--head": []}, None
    for a in argv:
        if a in groups:
            current = a
        elif not a.startswith("--") and current:
            groups[current].append(a)
    return groups["--base"], groups["--head"]


def main():
    base_runs, head_runs = split(sys.argv[1:])
    if not base_runs or not head_runs:
        sys.exit(__doc__)
    rows = check(medians(base_runs), medians(head_runs))
    if "--json" in sys.argv:
        print(json.dumps([{k: v for k, v in r.items() if k != "fmt"} for r in rows], indent=1))
    else:
        print(f"{len(base_runs)} base runs, {len(head_runs)} head runs, medians")
        print(f"  {'':10} {'base':>8} {'head':>8} {'may be worse by':>16}")
        for r in rows:
            f = r["fmt"].format
            print(f"  {r['measure']:10} {f(r['base']):>8} {f(r['head']):>8} {'(shown only)' if r['allowed'] is None else f(r['allowed']):>16}"
                  f"{'   WORSE' if r['failed'] else ''}")
    failed = [r["measure"] for r in rows if r["failed"]]
    if failed:
        print(f"FAIL: worse {', '.join(failed)}")
        sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()
