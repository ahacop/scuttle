#!/usr/bin/env python3
"""Mean and range of analyze.py's summary across runs. Usage: compare.py <run dir>... [--json]"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import analyze, scuttle_side, summary  # noqa: E402

runs = [Path(a) for a in sys.argv[1:] if not a.startswith("--")]
summaries = [summary(analyze(r)) for r in runs]
keys = ["stalls", "reversals", "torn", "gap", "rough", "hz", "stale", "ms", "border", "bfar", "bmax", "bjit", "stray",
        "missing", "unsettled", "orphans", "pjit", "pstall", "ptorn", "pgap", "pbord", "pbmax", "pbjit", "pbhid", "pstray",
        "pjitm", "pstallm", "pjits", "pstalls", "pslip", "pfreeze", "plat", "pdur"]
result = {k: dict(mean=sum(s[k] for s in summaries) / len(summaries), low=min(s[k] for s in summaries),
                  high=max(s[k] for s in summaries)) for k in keys}
# What scuttle logged about itself, where every run has it: the numbers only.
sides = [scuttle_side(r) for r in runs]
side_keys = [k for k in (sides[0] or {}) if all(s and isinstance(s.get(k), (int, float)) for s in sides)]
side = {k: dict(mean=sum(s[k] for s in sides) / len(sides), low=min(s[k] for s in sides), high=max(s[k] for s in sides))
        for k in side_keys}
if "--json" in sys.argv:
    print(json.dumps(dict(runs=len(runs), metrics=result, side=side), indent=1))
else:
    print(f"{len(runs)} runs")
    for k in keys:
        m = result[k]
        fmt = "{:.0%}" if k in ("stale", "bfar") else "{:.2f}" if k == "rough" else "{:.1f}"
        print(f"  {k:18} {fmt.format(m['mean']):>8}   range {fmt.format(m['low'])}–{fmt.format(m['high'])}")
    for k, m in side.items():
        fmt = "{:.0%}" if k == "main_busy" else "{:.2f}"
        print(f"  {k:18} {fmt.format(m['mean']):>8}   range {fmt.format(m['low'])}–{fmt.format(m['high'])}")
