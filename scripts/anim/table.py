#!/usr/bin/env python3
"""ab.sh's runs side by side: for each condition, a row per build with the mean of each on-screen measure over its
runs, and its range for the ones that vary most. With --commands, the same per command of the scenario, which is
where to look when a change helps one kind of command and hurts another.

Usage: table.py <ab.sh out dir> [--commands] [--keys pjit,pstall,...]"""
import re
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import analyze, summary  # noqa: E402

KEYS = ["pjit", "pjitm", "pjits", "pstall", "pslip", "pfreeze", "ptorn", "pgap", "pbord", "pbjit", "pbhid", "plat", "pdur"]


def main():
    out = Path(sys.argv[1])
    keys = KEYS
    if "--keys" in sys.argv:
        keys = sys.argv[sys.argv.index("--keys") + 1].split(",")
    runs = {}
    for d in sorted(out.iterdir()):
        m = re.fullmatch(r"(.+)-([a-z]+)-(glide|instant)-(\d+)", d.name)
        if m and (d / "trace.csv").exists():
            runs.setdefault(f"{m[2]}:{m[3]}", {}).setdefault(m[1], []).append(d)
    for condition, builds in runs.items():
        print(f"== {condition}")
        print(f"{'':24}{'runs':>5}" + "".join(f"{k:>14}" for k in keys))
        per_command = {}
        for name, dirs in builds.items():
            rows = [analyze(d) for d in dirs]
            sums = [summary(r) for r in rows]
            cells = []
            for k in keys:
                values = [s[k] for s in sums]
                cells.append(f"{statistics.mean(values):.1f} {min(values):.0f}-{max(values):.0f}")
            print(f"{name[:24]:24}{len(dirs):5d}" + "".join(f"{c:>14}" for c in cells))
            for r in rows:
                for n, row in enumerate(r):
                    per_command.setdefault((n, row["command"]), {}).setdefault(name, []).append(row)
        if "--commands" in sys.argv:
            for (n, command), by_build in sorted(per_command.items()):
                print(f"  {command}")
                for name, rows in by_build.items():
                    print(f"    {name[:20]:20}{len(rows):5d}" + "".join(f"{statistics.mean(r[k] for r in rows):14.1f}" for k in keys))
        print()


if __name__ == "__main__":
    main()
