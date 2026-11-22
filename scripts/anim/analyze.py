#!/usr/bin/env python3
"""Measures how smoothly scuttle animated the animtest windows, from run.sh's trace, events and draw logs.

For each command, every window's left and right edges are read on a 60 Hz grid, as the display shows them:

- ms: from the command to the last time any window moved
- states: how many distinct frames the window server showed the busiest window at
- stalls: grid frames where an edge that is still on its way doesn't move
- rev: an edge changing direction
- rough: how unevenly an edge moves, the sum of frame-to-frame speed changes over its distance travelled
  (0 for constant speed; a smooth ease adds a little)
- gap: the largest change, in points, in the gap between two columns that are neighbours, a small gap
  apart, both before and after: columns pulling apart or overlapping mid-animation
- torn: grid frames where the gap between such neighbours is off by more than 4 points
- hz: how often the window server showed a moving window at a new frame, on average
- stale: the share of grid frames where the app's last drawn width isn't the window's width, so its
  content is stretched or cut off

Usage: analyze.py <run dir> [--json]
"""
import bisect
import csv
import json
import sys
from pathlib import Path

FRAME = 1 / 60


def load(run):
    events = [(float(r["time"]), r["command"]) for r in csv.DictReader(open(run / "events.csv"))]
    trace = {}
    for r in csv.DictReader(open(run / "trace.csv")):
        x, w = float(r["x"]), float(r["width"])
        trace.setdefault(r["label"], []).append((float(r["time"]), x, x + w, w))
    draws = {}
    for log in run.glob("draw-*.log"):
        label = log.stem.split("-", 1)[1]
        draws[label] = [(float(t), int(w)) for t, _, w, _ in (line.strip().split(",") for line in open(log) if line.strip())]
    return events, trace, draws


def at(samples, times, t):
    """The last sample at or before t."""
    i = bisect.bisect_right(times, t) - 1
    return samples[max(i, 0)]


def edge_metrics(series):
    """series: an edge's position per grid frame."""
    moves = [b - a for a, b in zip(series, series[1:])]
    moving = [i for i, d in enumerate(moves) if abs(d) >= 0.5]
    # Rounding wobbles an edge by a point; only steps of 2 points or more count as a change of direction.
    if not moving:
        return dict(stalls=0, reversals=0, rough=0)
    active = moves[moving[0]:moving[-1] + 1]
    stalls = sum(1 for d in active if abs(d) < 0.5)
    signs = [1 if d > 0 else -1 for d in active if abs(d) >= 2]
    reversals = sum(1 for a, b in zip(signs, signs[1:]) if a != b)
    path = sum(abs(d) for d in active)
    rough = sum(abs(b - a) for a, b in zip(active, active[1:])) / path if path else 0
    return dict(stalls=stalls, reversals=reversals, rough=rough)


def analyze(run):
    events, trace, draws = load(run)
    labels = sorted(trace)
    times = {l: [s[0] for s in trace[l]] for l in labels}
    end = max(s[0] for l in labels for s in trace[l])
    rows = []
    for n, (t0, command) in enumerate(events):
        t1 = events[n + 1][0] if n + 1 < len(events) else end
        grid = [t0 + k * FRAME for k in range(int((t1 - t0) / FRAME))]
        if len(grid) < 3:
            continue
        per, intervals, stale, total = {}, [], 0, 0
        for l in labels:
            frames = [at(trace[l], times[l], t) for t in grid]
            changes = [s for s in trace[l] if t0 <= s[0] < t1]
            moved = [s[0] for a, s in zip(changes, changes[1:]) if (a[1], a[2]) != (s[1], s[2])]
            intervals += [b - a for a, b in zip(moved, moved[1:])]
            per[l] = dict(left=edge_metrics([f[1] for f in frames]), right=edge_metrics([f[2] for f in frames]),
                          frames=frames, duration=(moved[-1] - t0) * 1000 if moved else 0, states=len(moved))
            if moved and draws.get(l):
                dt = [d[0] for d in draws[l]]
                for t, f in zip(grid, frames):
                    if t > moved[-1] + 0.1:
                        break
                    total += 1
                    stale += abs(draws[l][max(bisect.bisect_right(dt, t) - 1, 0)][1] - f[3]) > 1
        gap, torn_frames = 0.0, set()
        for a in labels:
            for b in labels:
                fa, fb = per[a]["frames"], per[b]["frames"]
                before, after = fb[0][1] - fa[0][2], fb[-1][1] - fa[-1][2]
                if a != b and 0 <= before <= 50 and 0 <= after <= 50:
                    for k, (x, y) in enumerate(zip(fa, fb)):
                        error = abs((y[1] - x[2]) - after)
                        gap = max(gap, error)
                        if error > 4:
                            torn_frames.add(k)
        edges = [per[l][e] for l in labels for e in ("left", "right")]
        rows.append(dict(
            command=command,
            ms=max(per[l]["duration"] for l in labels),
            states=max(per[l]["states"] for l in labels),
            stalls=sum(e["stalls"] for e in edges),
            reversals=sum(e["reversals"] for e in edges),
            rough=max(e["rough"] for e in edges),
            gap=gap,
            torn=len(torn_frames),
            hz=len(intervals) / sum(intervals) if intervals else 0,
            stale=stale / total if total else 0,
        ))
    return rows


def scuttle_side(run):
    """From scuttle's own animation log, if it kept one: how often it stepped while animating, and how long a step took."""
    path = run / "scuttle.log"
    if not path.exists():
        return None
    steps = [(float(t), float(ms)) for kind, t, ms, *_ in (l.strip().split(",") for l in open(path) if l.startswith("step,"))]
    gaps = [b[0] - a[0] for a, b in zip(steps, steps[1:]) if b[0] - a[0] < 0.1]
    if not gaps:
        return None
    gaps.sort()
    side = dict(tick_hz=len(gaps) / sum(gaps), tick_p95_ms=gaps[int(len(gaps) * 0.95)] * 1000,
                step_ms_mean=sum(ms for _, ms in steps) / len(steps), step_ms_max=max(ms for _, ms in steps))
    borders = run / "borders.log"
    if borders.exists():
        # Border work while animating: flushes within an animation's span of steps.
        times = [t for t, _ in steps]
        flushes = [(float(t), float(ms)) for _, t, ms, *_ in (l.strip().split(",") for l in open(borders) if l.startswith("border,"))]
        busy = [ms for t, ms in flushes if any(abs(t - s) < 0.05 for s in times[::5])]
        side.update(border_flushes=len(busy), border_ms_mean=sum(busy) / len(busy) if busy else 0,
                    border_ms_max=max(busy) if busy else 0, border_ms_total=sum(busy))
    return side


def summary(rows):
    moving = [r for r in rows if r["states"]]
    return dict(
        stalls=sum(r["stalls"] for r in rows),
        reversals=sum(r["reversals"] for r in rows),
        gap=max(r["gap"] for r in rows),
        torn=sum(r["torn"] for r in rows),
        rough=max(r["rough"] for r in rows),
        hz=sum(r["hz"] for r in moving) / len(moving),
        stale=sum(r["stale"] for r in moving) / len(moving),
        ms=sum(r["ms"] for r in moving) / len(moving),
    )


def main():
    run = Path(sys.argv[1])
    rows = analyze(run)
    if "--json" in sys.argv:
        print(json.dumps(dict(rows=rows, summary=summary(rows)), indent=1))
        return
    print(f"{'command':28} {'ms':>5} {'states':>6} {'stalls':>6} {'rev':>4} {'rough':>6} {'gap':>6} {'torn':>5} {'hz':>5} {'stale':>6}")
    for r in rows:
        print(f"{r['command'][:28]:28} {r['ms']:5.0f} {r['states']:6d} {r['stalls']:6d} {r['reversals']:4d} "
              f"{r['rough']:6.2f} {r['gap']:6.1f} {r['torn']:5d} {r['hz']:5.1f} {r['stale']:6.0%}")
    side = scuttle_side(run)
    if side:
        print(f"SCUTTLE ticks {side['tick_hz']:.1f} Hz (p95 interval {side['tick_p95_ms']:.1f} ms), "
              f"step {side['step_ms_mean']:.2f} ms mean, {side['step_ms_max']:.2f} ms max")
        if "border_flushes" in side:
            print(f"BORDERS {side['border_flushes']} flushes while animating, {side['border_ms_mean']:.1f} ms mean, "
                  f"{side['border_ms_max']:.1f} ms max, {side['border_ms_total']:.0f} ms total")
    s = summary(rows)
    print(f"SUMMARY stalls {s['stalls']}  rev {s['reversals']}  torn {s['torn']}  worst gap {s['gap']:.0f}  worst rough {s['rough']:.2f}  "
          f"hz {s['hz']:.1f}  stale {s['stale']:.0%}  ms {s['ms']:.0f}")


if __name__ == "__main__":
    main()
