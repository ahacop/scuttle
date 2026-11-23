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
- border: how far, in points, a border piece's worst edge is from where its window puts it: mean over the frames
  while windows move, the share of them off by more than 4 points (`bfar`) and the worst (`bmax`). `bjit` is how
  much that error swings from one frame to the next; `stray` counts pieces somewhere their window never asked
  them to be (the corner of the screen), `missing` pieces gone while their window moves, `unsettled` pieces off
  their window once it has stopped. See borders.py. A trace without piece ids (an older recording) only gets
  `border` and `bfar`, from the top piece's left and right edges
- stale: the share of grid frames where the app's last drawn width isn't the window's width, so its
  content is stretched or cut off

The `p` measures are the same things read from the screen recording, frame by frame as the display showed them:
see pixels.py. They are there when the run has its recording and its screen.json.

Usage: analyze.py <run dir> [--json] [--no-pixels]
"""
import bisect
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import borders as border_pieces  # noqa: E402
import pixels  # noqa: E402

PIXEL_KEYS = ["pjit", "pstall", "ptorn", "pgap", "pbord", "pbmax", "pbjit", "pbhid", "pstray"]

FRAME = 1 / 60


def load(run):
    events = [(float(r["time"]), r["command"]) for r in csv.DictReader((run / "events.csv").read_text().splitlines())]
    trace, borders = {}, {}
    # For borders.py: every frame by sample time, windows by label and border pieces by window id.
    rects = dict(windows={}, pieces={}, times=set())
    for r in csv.DictReader((run / "trace.csv").read_text().splitlines()):
        x, w = float(r["x"]), float(r["width"])
        rect = (x, float(r["y"]), w, float(r["height"]))
        rects["times"].add(float(r["time"]))
        if r["label"] == "border":
            borders.setdefault(float(r["time"]), []).append(rect)
            if r.get("id"):
                rects["pieces"].setdefault(r["id"], {})[float(r["time"])] = rect
            continue
        rects["windows"].setdefault(r["label"], {})[float(r["time"])] = rect
        trace.setdefault(r["label"], []).append((float(r["time"]), x, x + w, w, float(r["y"])))
    rects["times"] = sorted(rects["times"])
    load.rects = rects
    draws = {}
    for log in run.glob("draw-*.log"):
        label = log.stem.split("-", 1)[1]
        draws[label] = [(float(t), int(w)) for t, _, w, _ in (line.strip().split(",") for line in log.read_text().splitlines() if line.strip())]
    return events, trace, draws, borders


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


def recording(run, trace, labels):
    """The recording's readings and the frame of it that the trace's time `t` falls in, or None without a recording."""
    if not ((run / "screen.mp4").exists() and (run / "screen.json").exists()):
        return None
    try:
        data = pixels.extract(run)
    except (OSError, ValueError, KeyError) as error:
        print(f"no pixel measures: {error}", file=sys.stderr)
        return None
    start = min(s[0][0] for s in trace.values())
    end = max(s[-1][0] for s in trace.values())
    times = {l: [s[0] for s in trace[l]] for l in labels}
    grid = []
    for j in range(int((end - start) / FRAME)):
        t = start + j * FRAME
        grid.append({l: at(trace[l], times[l], t)[1:3] for l in labels if trace[l][0][0] <= t})
    shift = pixels.synchronize(data["frames"], grid)
    if shift is None:
        return None
    return data, lambda t: round((t - start) / FRAME) + shift


def border_width(run):
    """The border's width in the config the run recorded with; 4, config.py's, without one."""
    try:
        import tomllib
        return tomllib.loads((run / "scuttle.toml").read_text())["borders"]["width"]
    except (OSError, KeyError, ValueError):
        return 4


def analyze(run, with_pixels=True):
    events, trace, draws, borders = load(run)
    labels = sorted(trace)
    video = recording(run, trace, labels) if with_pixels else None
    border_times = sorted(borders)
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
        # Border lag: each moving window's top border piece against the window's edges, while it moves.
        border_errors = []
        if border_times:
            width = None
            for l in labels:
                if not per[l]["states"]:
                    continue
                for t, f in zip(grid, per[l]["frames"]):
                    if t > t0 + per[l]["duration"] / 1000 + 0.05:
                        break
                    rects = borders[border_times[max(bisect.bisect_right(border_times, t) - 1, 0)]]
                    _, left, right, _, top = f
                    # The top piece: just above the window, as wide as it give or take the border, overlapping it.
                    tops = [r for r in rects if abs((r[1] + r[3]) - top) <= 30 and r[3] <= 40 and r[0] < right and r[0] + r[2] > left]
                    if not tops:
                        continue
                    piece = min(tops, key=lambda r: abs(r[0] - left) + abs(r[0] + r[2] - right))
                    w = (piece[2] - (right - left)) / 2 if width is None else width
                    width = width if width is not None else max(0.0, round(w))
                    border_errors.append(max(abs(piece[0] - (left - width)), abs(piece[0] + piece[2] - (right + width))))
        edges = [per[l][e] for l in labels for e in ("left", "right")]
        pieces = dict(border=sum(border_errors) / len(border_errors) if border_errors else 0,
                      bfar=sum(e > 4 for e in border_errors) / len(border_errors) if border_errors else 0,
                      bmax=0, bjit=0, stray=0, missing=0, unsettled=0, orphans=0)
        rects = load.rects
        if rects["pieces"]:
            pieces = border_pieces.measure(rects["windows"], rects["pieces"], rects["times"], grid,
                                           t0 + max(per[l]["duration"] for l in labels) / 1000, border_width(run))
            pieces.pop("pieces")
        shown = None
        if video:
            data, frame_of = video
            shown = pixels.measure(data, max(frame_of(t0), 0), min(frame_of(t1), len(data["frames"])))
        pieces.update(shown or {**{k: 0 for k in PIXEL_KEYS}, "pborders": False})
        pieces["pixels"] = shown is not None
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
            **pieces,
        ))
    return rows


def lines(path, kind):
    """The fields after the kind of every `<kind>,...` line of a log; nothing if the log is not there."""
    if not path.exists():
        return []
    return [l.strip().split(",")[1:] for l in open(path) if l.startswith(kind + ",")]


def p95(values):
    return sorted(values)[int(len(values) * 0.95)] if values else 0


EVENT_KINDS = {723: "update", 804: "close", 806: "move", 807: "resize", 808: "reorder", 811: "level", 1322: "title",
               1325: "create", 1326: "destroy", 1401: "space", 1508: "front-app"}


def scuttle_side(run):
    """From scuttle's own logs, if it kept them: how often it stepped while animating and how long a step took, and
    what the animation cost elsewhere while it ran: border work and window events on the main thread, and the
    Accessibility writes to the apps."""
    steps = [(float(t), float(ms)) for t, ms, *_ in lines(run / "scuttle.log", "step")]
    gaps = sorted(b[0] - a[0] for a, b in zip(steps, steps[1:]) if b[0] - a[0] < 0.1)
    if not gaps:
        return None
    side = dict(tick_hz=len(gaps) / sum(gaps), tick_p95_ms=gaps[int(len(gaps) * 0.95)] * 1000,
                step_ms_mean=sum(ms for _, ms in steps) / len(steps), step_ms_max=max(ms for _, ms in steps))
    times = [t for t, _ in steps]
    animating = sum(gaps) + FRAME

    def busy(t):
        """Whether an animation was stepping within 50 ms of t."""
        i = bisect.bisect_left(times, t)
        return any(0 <= j < len(times) and abs(times[j] - t) < 0.05 for j in (i - 1, i))

    main = 0.0
    flushes = [float(ms) for t, ms, *_ in lines(run / "borders.log", "border") if busy(float(t))]
    if (run / "borders.log").exists():
        side.update(border_flushes=len(flushes), border_ms_mean=sum(flushes) / len(flushes) if flushes else 0,
                    border_ms_max=max(flushes, default=0), border_ms_total=sum(flushes))
        main += sum(flushes)
    tracks = [(float(t), float(ms)) for t, ms, *_ in lines(run / "borders.log", "track") if busy(float(t))]
    if tracks:
        ms = [m for _, m in tracks]
        side.update(track_ticks=len(ms), track_ms_mean=sum(ms) / len(ms), track_ms_p95=p95(ms), track_ms_max=max(ms),
                    track_ms_total=sum(ms))
        main += sum(ms)
    events = [(int(kind), float(wait), float(ms)) for t, kind, wait, ms in lines(run / "events.log", "event") if busy(float(t))]
    if events:
        by_kind = {}
        for kind, _, ms in events:
            name = EVENT_KINDS.get(kind, str(kind))
            n, total = by_kind.get(name, (0, 0.0))
            by_kind[name] = (n + 1, total + ms)
        waits = [w for _, w, _ in events]
        side.update(events=len(events), event_ms_total=sum(ms for _, _, ms in events),
                    event_wait_ms_mean=sum(waits) / len(waits), event_wait_ms_p95=p95(waits), event_wait_ms_max=max(waits),
                    event_kinds={k: dict(count=n, ms=total) for k, (n, total) in sorted(by_kind.items(), key=lambda i: -i[1][1])})
        main += side["event_ms_total"]
    if main:
        # The share of the animations' time the main thread spent on their events and borders.
        side["main_busy"] = main / 1000 / animating
    writes = [(kind, float(ms)) for t, kind, ms in lines(run / "ax.log", "ax") if busy(float(t))]
    if writes:
        ms = [m for _, m in writes]
        side.update(ax_writes=len(ms), ax_ms_mean=sum(ms) / len(ms), ax_ms_p95=p95(ms), ax_ms_max=max(ms), ax_ms_total=sum(ms),
                    ax_per_step=len(ms) / len(steps),
                    ax_kinds={k: dict(count=len(v), ms_mean=sum(v) / len(v), ms_p95=p95(v))
                              for k in sorted({k for k, _ in writes}) for v in [[m for kk, m in writes if kk == k]]})
    side["animating_s"] = animating
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
        border=sum(r["border"] for r in moving) / len(moving),
        bfar=sum(r["bfar"] for r in moving) / len(moving),
        bmax=max(r["bmax"] for r in rows),
        bjit=sum(r["bjit"] for r in moving) / len(moving),
        stray=sum(r["stray"] for r in rows),
        missing=sum(r["missing"] for r in rows),
        unsettled=sum(r["unsettled"] for r in rows),
        orphans=max(r["orphans"] for r in rows),
        pjit=sum(r["pjit"] for r in moving) / len(moving),
        pstall=sum(r["pstall"] for r in rows),
        ptorn=sum(r["ptorn"] for r in rows),
        pgap=max(r["pgap"] for r in rows),
        pbord=sum(r["pbord"] for r in moving) / len(moving),
        pbmax=max(r["pbmax"] for r in rows),
        pbjit=sum(r["pbjit"] for r in moving) / len(moving),
        pbhid=sum(r["pbhid"] for r in rows),
        pstray=sum(r["pstray"] for r in rows),
        pixels=all(r["pixels"] for r in rows),
        pborders=any(r["pborders"] for r in rows),
    )


def main():
    run = Path(sys.argv[1])
    rows = analyze(run, with_pixels="--no-pixels" not in sys.argv)
    side = scuttle_side(run)
    if "--json" in sys.argv:
        print(json.dumps(dict(rows=rows, summary=summary(rows), side=side), indent=1))
        return
    print(f"{'command':28} {'ms':>5} {'states':>6} {'stalls':>6} {'rev':>4} {'rough':>6} {'gap':>6} {'torn':>5} {'hz':>5} {'stale':>6} {'border':>7} {'bfar':>5} {'bmax':>5} {'bjit':>5} {'stray':>5} {'miss':>5} {'unset':>5}")
    for r in rows:
        print(f"{r['command'][:28]:28} {r['ms']:5.0f} {r['states']:6d} {r['stalls']:6d} {r['reversals']:4d} "
              f"{r['rough']:6.2f} {r['gap']:6.1f} {r['torn']:5d} {r['hz']:5.1f} {r['stale']:6.0%} {r['border']:7.1f} {r['bfar']:5.0%} "
              f"{r['bmax']:5.0f} {r['bjit']:5.1f} {r['stray']:5d} {r['missing']:5d} {r['unsettled']:5d}")
    if all(r["pixels"] for r in rows):
        print(f"\n{'on screen':28} {'pjit':>5} {'pstall':>6} {'ptorn':>5} {'pgap':>6} {'pbord':>6} {'pbmax':>6} {'pbjit':>6} {'pbhid':>6} {'pstray':>6}")
        for r in rows:
            print(f"{r['command'][:28]:28} {r['pjit']:5.1f} {r['pstall']:6d} {r['ptorn']:5d} {r['pgap']:6.0f} {r['pbord']:6.1f} "
                  f"{r['pbmax']:6.0f} {r['pbjit']:6.1f} {r['pbhid']:6d} {r['pstray']:6d}")
        print()
    if side:
        print(f"SCUTTLE ticks {side['tick_hz']:.1f} Hz (p95 interval {side['tick_p95_ms']:.1f} ms), "
              f"step {side['step_ms_mean']:.2f} ms mean, {side['step_ms_max']:.2f} ms max, animating {side['animating_s']:.2f} s")
        if "border_flushes" in side:
            print(f"BORDERS {side['border_flushes']} flushes while animating, {side['border_ms_mean']:.1f} ms mean, "
                  f"{side['border_ms_max']:.1f} ms max, {side['border_ms_total']:.0f} ms total")
        if "track_ticks" in side:
            print(f"TRACKER {side['track_ticks']} ticks, {side['track_ms_mean']:.2f} ms mean, {side['track_ms_p95']:.2f} ms p95, "
                  f"{side['track_ms_max']:.1f} ms max, {side['track_ms_total']:.0f} ms total")
        if "events" in side:
            kinds = ", ".join(f"{k} {v['count']}x {v['ms']:.0f} ms" for k, v in side["event_kinds"].items())
            print(f"EVENTS {side['events']} while animating, {side['event_ms_total']:.0f} ms handling them ({kinds}); "
                  f"waited for the main thread {side['event_wait_ms_mean']:.1f} ms mean, {side['event_wait_ms_p95']:.1f} ms p95, "
                  f"{side['event_wait_ms_max']:.0f} ms max")
        if "main_busy" in side:
            print(f"MAIN THREAD busy {side['main_busy']:.0%} of the time animating")
        if "ax_writes" in side:
            kinds = ", ".join(f"{k} {v['count']}x {v['ms_mean']:.2f} ms (p95 {v['ms_p95']:.1f})" for k, v in side["ax_kinds"].items())
            print(f"AX {side['ax_writes']} writes, {side['ax_per_step']:.1f} a step, {side['ax_ms_mean']:.2f} ms mean, "
                  f"{side['ax_ms_p95']:.1f} ms p95, {side['ax_ms_max']:.0f} ms max, {side['ax_ms_total']:.0f} ms total: {kinds}")
    s = summary(rows)
    print(f"SUMMARY stalls {s['stalls']}  rev {s['reversals']}  torn {s['torn']}  worst gap {s['gap']:.0f}  worst rough {s['rough']:.2f}  "
          f"hz {s['hz']:.1f}  stale {s['stale']:.0%}  ms {s['ms']:.0f}  border {s['border']:.1f}  bfar {s['bfar']:.0%}  bmax {s['bmax']:.0f}  bjit {s['bjit']:.1f}  "
          f"stray {s['stray']}  missing {s['missing']}  unsettled {s['unsettled']}  orphans {s['orphans']}")
    if s["pixels"]:
        print(f"ON SCREEN pjit {s['pjit']:.1f}  pstall {s['pstall']}  ptorn {s['ptorn']}  worst pgap {s['pgap']:.0f}  pbord {s['pbord']:.1f}  "
              f"pbmax {s['pbmax']:.0f}  pbjit {s['pbjit']:.1f}  pbhid {s['pbhid']}  pstray {s['pstray']}")


if __name__ == "__main__":
    main()
