#!/usr/bin/env python3
"""Mean and range of analyze.py's summary across runs. Usage: compare.py <run dir>... [--json]"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import analyze, summary  # noqa: E402

runs = [Path(a) for a in sys.argv[1:] if not a.startswith("--")]
summaries = [summary(analyze(r)) for r in runs]
keys = ["stalls", "reversals", "torn", "gap", "rough", "hz", "stale", "ms", "border", "bfar"]
result = {k: dict(mean=sum(s[k] for s in summaries) / len(summaries), low=min(s[k] for s in summaries),
                  high=max(s[k] for s in summaries)) for k in keys}
if "--json" in sys.argv:
    print(json.dumps(dict(runs=len(runs), metrics=result), indent=1))
else:
    print(f"{len(runs)} runs")
    for k in keys:
        m = result[k]
        fmt = "{:.0%}" if k in ("stale", "bfar") else "{:.2f}" if k == "rough" else "{:.1f}"
        print(f"  {k:10} {fmt.format(m['mean']):>8}   range {fmt.format(m['low'])}–{fmt.format(m['high'])}")
