#!/usr/bin/env python3
"""ab.sh's runs side by side: for each condition, a row per build with the mean of each on-screen measure over its
runs and its range. A `*` marks a range that doesn't overlap the first build's: with a few runs each, anything
else is within what two recordings of one build differ by. Name the same build twice to see that noise: with
three runs it stars about one cell in twenty, so one star alone says nothing; several measures of one command
moving together do. With --commands, the same per command of the scenario, which is
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
        per_command, first = {}, {}
        for name, dirs in builds.items():
            rows = [analyze(d) for d in dirs]
            sums = [summary(r) for r in rows]
            cells = []
            for k in keys:
                values = [s[k] for s in sums]
                # Against the first build: only ranges that don't overlap are a difference the runs show.
                low, high = first.setdefault(k, (min(values), max(values)))
                clear = "*" if min(values) > high or max(values) < low else ""
                cells.append(f"{statistics.mean(values):.1f} {min(values):.0f}-{max(values):.0f}{clear}")
            print(f"{name[:24]:24}{len(dirs):5d}" + "".join(f"{c:>14}" for c in cells))
            for r in rows:
                for n, row in enumerate(r):
                    per_command.setdefault((n, row["command"]), {}).setdefault(name, []).append(row)
        if "--commands" in sys.argv:
            for (n, command), by_build in sorted(per_command.items()):
                print(f"  {command}")
                base = None
                for name, rows in by_build.items():
                    spans = {k: (min(r[k] for r in rows), max(r[k] for r in rows)) for k in keys}
                    base = base or spans
                    cells = [f"{statistics.mean(r[k] for r in rows):.1f}" + ("*" if spans[k][0] > base[k][1] or spans[k][1] < base[k][0] else "")
                             for k in keys]
                    print(f"    {name[:20]:20}{len(rows):5d}" + "".join(f"{c:>14}" for c in cells))
        print()


if __name__ == "__main__":
    main()
