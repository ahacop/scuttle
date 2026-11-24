"""Measures an animation from run.sh's screen recording: what reached the screen, frame by frame.

The trace says where the window server had each window whenever it was asked, every 4 ms. That is not what the
display showed: frames are composed 60 times a second, a window's new size shows only once its app has drawn, and a
border and its window can be right in the trace and a frame apart on screen. So three rows of pixels are read from
every frame of the recording:

- one across the windows, a quarter of the way down the screen. Every test window is one colour, so its left and
  right edges are where that colour starts and ends. The borders' side pieces cross this row too, in the two
  colours config.py gives them and nothing else on screen has: a window's are the run of border colour left of it
  and the one right of it
- one through the menu bar and one just under the top of the screen, where no border belongs

From them, for each command (all in points):

- pjit: how far a moving edge is from where the two frames before it and the two after say it should be, on
  average: the curve through those four, which is the glide's own curve, so a smooth glide scores next to nothing
  however far and fast it goes, and a frame shown twice and then caught up scores most of a frame's travel
- pstall: frames where a window edge on its way stands still
- pjitm, pstallm and pjits, pstalls: the two above for windows that were only moved and for those resized, whose
  apps have to draw before a step shows
- pslip: stalls never made up for, after which the window is shown a frame later than before
- pfreeze: frames on which no edge on its way moved: the display showed nothing new at all
- plat, pdur: milliseconds from the command to the first frame an edge moved on, and to the last
- ptorn, pgap: frames where the gap between neighbouring columns is off by more than 4 points, and the worst
- pbord, pbmax: how far a border's side piece is from where it sits against its window at rest, mean and worst
- pbjit: how much that changes from one frame to the next: a border that trails steadily scores 0, one that jumps
  ahead of its window and falls behind scores its swing
- pbhid: frames where a moving window's side piece can't be found, hidden under a neighbour or not drawn
- pstray: frames with border colour in the menu bar or along the top of the screen

`pborders` says whether any border colour was seen: a build from before `SCUTTLE_CONFIG` draws its borders in your
colours, which the recording can't be read by.

Usage: pixels.py <run dir>   (prints the per-frame readings' summary; analyze.py adds the measures to its table)
"""
import json
import subprocess
import sys
import tomllib
from pathlib import Path

# The test windows' colours, as run.sh and scenario.txt give them: strong ones a wallpaper is unlikely to have.
FILLS = {"A": "#d81b60", "B": "#00a651", "C": "#ff8f00", "D": "#6a1b9a"}
STRIPE = 0.65  # animtest's stripes are the fill under 35% black
STEP = 6
FPS = 60


def rgb(hex_colour):
    v = int(hex_colour.lstrip("#")[:6], 16)
    return (v >> 16) & 255, (v >> 8) & 255, v & 255


def near(colour, limit):
    cr, cg, cb = colour
    limit *= limit
    return lambda r, g, b: (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2 <= limit


def window_classifier():
    shades = []
    for label, fill in FILLS.items():
        c = rgb(fill)
        shades += [(label, c), (label, tuple(round(x * STRIPE) for x in c))]

    def classify(r, g, b):
        best, found = 45 * 45, None
        for label, (cr, cg, cb) in shades:
            d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
            if d < best:
                best, found = d, label
        return found
    return classify


def read_row(row, width, classify, is_border):
    """Window spans and border runs in one row of rgb24 pixels: ({label: [left, right]}, [[start, end, kind]])."""
    # A window is the longest stretch of its colour: a speck of it in the wallpaper is not the window.
    spans, stretch = {}, None
    for x in range(0, width + STEP, STEP):
        label = classify(row[3 * x], row[3 * x + 1], row[3 * x + 2]) if x < width else None
        if stretch and label != stretch[0]:
            best = spans.get(stretch[0])
            if stretch[2] - stretch[1] >= 5 * STEP and (best is None or stretch[2] - stretch[1] > best[1] - best[0]):
                spans[stretch[0]] = [stretch[1], stretch[2]]
            stretch = None
        if label:
            stretch = [label, stretch[1] if stretch else x, x]
    for label, span in spans.items():
        left, right = span
        while left > 0 and classify(*row[3 * (left - 1):3 * left]) == label:
            left -= 1
        while right < width - 1 and classify(*row[3 * (right + 1):3 * (right + 2)]) == label:
            right += 1
        spans[label] = [left, right + 1]
    return spans, border_runs(row, width, is_border)


def border_runs(row, width, is_border):
    runs, start, kind = [], None, None
    reds, greens, blues = row[0::3], row[1::3], row[2::3]
    for x in range(width):
        r, g, b = reds[x], greens[x], blues[x]
        k = 0 if is_border[0](r, g, b) else 1 if is_border[1](r, g, b) else None
        if k != kind:
            if kind is not None:
                runs.append([start, x, kind])
            start, kind = x, k
    if kind is not None:
        runs.append([start, width, kind])
    return runs


def rows_for(run):
    """The pixel rows to read and the pixels per point, from the screen's size and the recording's."""
    screen = json.loads((run / "screen.json").read_text())
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                            "-of", "csv=p=0", str(run / "screen.mp4")], capture_output=True, text=True, check=True)
    width, height = (int(v) for v in probe.stdout.strip().split(",")[:2])
    scale = width / screen["width"]
    return width, height, scale, [height // 4, round(10 * scale), 1]


def extract(run):
    """Every frame's readings, kept in pixels.json beside the recording: reading it takes a few seconds."""
    cache = run / "pixels.json"
    if cache.exists() and cache.stat().st_mtime >= (run / "screen.mp4").stat().st_mtime:
        return json.loads(cache.read_text())
    width, height, scale, rows = rows_for(run)
    colours = {"active-color": "#ff00ff", "inactive-color": "#00ffff"}
    if (run / "scuttle.toml").exists():
        colours.update({k: v for k, v in tomllib.loads((run / "scuttle.toml").read_text()).get("borders", {}).items() if k in colours})
    is_border = [near(rgb(colours["active-color"]), 90), near(rgb(colours["inactive-color"]), 90)]
    classify = window_classifier()
    # In rgb first: a row one pixel high has no height in the recording's own format, whose colour is at half size.
    crops = ";".join(f"[v{i}]crop=iw:1:0:{y}:exact=1[r{i}]" for i, y in enumerate(rows))
    graph = f"format=rgb24,split={len(rows)}" + "".join(f"[v{i}]" for i in range(len(rows))) + ";" + crops + ";" \
        + "".join(f"[r{i}]" for i in range(len(rows))) + f"vstack={len(rows)}"
    video = subprocess.run(["ffmpeg", "-v", "error", "-i", str(run / "screen.mp4"), "-filter_complex", graph,
                            "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    size = width * 3
    frames = []
    for at in range(0, len(video) - len(rows) * size + 1, len(rows) * size):
        spans, runs = read_row(video[at:at + size], width, classify, is_border)
        stray = sum(end - start for i in (1, 2)
                    for start, end, _ in border_runs(video[at + i * size:at + (i + 1) * size], width, is_border))
        frames.append(dict(w={l: [v / scale for v in s] for l, s in spans.items()},
                           b=[[start / scale, end / scale, kind] for start, end, kind in runs], stray=stray / scale))
    data = dict(frames=frames, width=width / scale)
    cache.write_text(json.dumps(data))
    return data


def synchronize(frames, grid_frames):
    """How many grid frames before the recording's first frame the trace's first is: the shift at which the windows
    the recording shows are nearest those the trace has. `grid_frames`: the trace's windows on a 60 Hz grid, as
    {label: (left, right)} per frame."""
    best = None
    for shift in range(-120, 420):
        total, count = 0.0, 0
        for k in range(0, len(frames), 3):
            j = k - shift
            if not 0 <= j < len(grid_frames):
                continue
            for label, (left, right) in frames[k]["w"].items():
                if label in grid_frames[j]:
                    want = grid_frames[j][label]
                    # The screen cuts a window off at its edges; the trace doesn't.
                    total += min(abs(left - want[0]), 400) + min(abs(right - want[1]), 400)
                    count += 2
        if count >= 100 and (best is None or total / count < best[0]):
            best = (total / count, shift)
    return best[1] if best else None


def sides(frame, width):
    """Each window's side pieces in a frame: {label: (left piece's left edge or None, right piece's right edge or None)},
    each from the window edge it belongs to. Between two windows, the first run of border colour is the right piece of
    the window on the left and the last the left piece of the window on the right; a lone run there is the piece of
    the edge it is nearer. Left of the first window and right of the last, the nearest run is that window's."""
    spans = sorted(frame["w"].items(), key=lambda item: item[1][0])
    found = {label: [None, None] for label, _ in spans}
    for n in range(len(spans) + 1):
        before, after = spans[n - 1] if n else None, spans[n] if n < len(spans) else None
        low, high = before[1][1] if before else -1e9, after[1][0] if after else 1e9
        runs = [r for r in frame["b"] if low - 2 <= r[0] and r[1] <= high + 2]
        if not runs:
            continue
        if before and after and len(runs) == 1:
            nearer_left = abs(runs[0][0] - low) <= abs(runs[0][1] - high)
            runs = [runs[0], None] if nearer_left else [None, runs[0]]
        if before and runs[0]:
            found[before[0]][1] = runs[0][1] - low
        if after and runs[-1]:
            found[after[0]][0] = runs[-1][0] - high
    for label, (left, right) in spans:
        if left <= 1:
            found[label][0] = None
        if right >= width - 1:
            found[label][1] = None
    return {label: tuple(pair) for label, pair in found.items()}


def made_up(xs, k):
    """Whether the frame an edge stood still on (`xs[k]` is `xs[k - 1]`) was made up for: the step before or after it
    covers about two frames' travel, going by the steps either side of those. A stall never made up for is the
    window shown a frame later from then on."""
    def step(i):
        return abs(xs[i] - xs[i - 1]) if 0 < i < len(xs) and None not in (xs[i], xs[i - 1]) else None
    around = [d for d in (step(k - 2), step(k + 2)) if d is not None and d >= 1]
    beside = [d for d in (step(k - 1), step(k + 1)) if d is not None]
    if not around or not beside:
        return False
    return max(beside) >= 1.6 * sum(around) / len(around)


def settled(xs, changes):
    """`changes` without the stragglers: a change of a few points long after the glide stopped (a shadow or a
    border settling, the encoder) or long before it began is not the glide still going, and counting the still
    frames between as stalls makes a clean glide look like the worst."""
    changes = list(changes)
    while len(changes) > 1 and changes[-1] - changes[-2] > 6 and abs(xs[changes[-1]] - xs[changes[-2]]) < 16:
        changes.pop()
    while len(changes) > 1 and changes[1] - changes[0] > 6 and abs(xs[changes[0]] - xs[changes[0] - 1]) < 16:
        changes.pop(0)
    return changes


def measure(data, first, last):
    """The measures of the frames first..last of a recording, one command's."""
    frames, width = data["frames"][first:last], data["width"]
    if len(frames) < 4:
        return None
    labels = sorted({l for f in frames for l in f["w"]})
    series = {l: [f["w"].get(l) for f in frames] for l in labels}

    def covered(k, label, side):
        """Whether another window is right against this edge: it is then where that window covers this one, not
        this one's own edge. Columns keep a gap."""
        x = series[label][k][side]
        return any(o != label and series[o][k] and series[o][k][0] - 3 <= x <= series[o][k][1] + 3 for o in labels)

    def resized(label):
        """Whether the window's width changes: its app has to draw for every step, where one only moved has not."""
        widths = [s[1] - s[0] for s in series[label] if s and s[0] > 1 and s[1] < width - 1]
        return bool(widths) and max(widths) - min(widths) > 8

    jitter, stalls, moving = [], 0, set()
    # The same by what was asked of the window, [moved, resized]; stalls never made up for; and per frame, the
    # edges on their way and those of them that moved.
    kinds, slips, first_change, last_change = [dict(jitter=[], stalls=0), dict(jitter=[], stalls=0)], 0, None, None
    under_way, changed = [0] * len(frames), [0] * len(frames)
    for label, spans in series.items():
        kind = kinds[resized(label)]
        for side in (0, 1):
            xs = [s[side] if s else None for s in spans]
            # An edge at the screen's edge is the screen's, not the window's.
            xs = [x if x is not None and 1 < x < width - 1 and not covered(k, label, side) else None for k, x in enumerate(xs)]
            changes = [k for k in range(1, len(xs)) if xs[k] is not None and xs[k - 1] is not None and abs(xs[k] - xs[k - 1]) >= 1]
            changes = settled(xs, changes)
            if not changes or abs(xs[changes[-1]] - xs[changes[0] - 1]) < 8:
                continue
            start, end = changes[0], changes[-1]
            first_change = start if first_change is None else min(first_change, start)
            last_change = end if last_change is None else max(last_change, end)
            moving.update(range(start - 1, end + 2))
            for k in range(start, end):
                if None in (xs[k - 1], xs[k]):
                    continue
                under_way[k] += 1
                still = abs(xs[k] - xs[k - 1]) < 1
                changed[k] += not still
                stalls += still
                kind["stalls"] += still
                if still:
                    slips += not made_up(xs, k)
                # Within the glide only: where it starts and stops, the curve through the neighbours has a corner.
                if start + 1 <= k <= end - 2 and k + 2 < len(xs) and None not in (xs[k - 2], xs[k + 1], xs[k + 2]):
                    off = abs(xs[k] - (-xs[k - 2] + 4 * xs[k - 1] + 4 * xs[k + 1] - xs[k + 2]) / 6)
                    jitter.append(off)
                    kind["jitter"].append(off)
    gap, torn = 0.0, set()
    for a in labels:
        for b in labels:
            pairs = [(x[1], y[0]) for x, y in zip(series[a], series[b]) if x and y]
            if a == b or len(pairs) < len(frames) or not (0 <= pairs[0][1] - pairs[0][0] <= 60 and 0 <= pairs[-1][1] - pairs[-1][0] <= 60):
                continue
            for k, (right, left) in enumerate(pairs):
                error = abs((left - right) - (pairs[-1][1] - pairs[-1][0]))
                gap = max(gap, error)
                if error > 4:
                    torn.add(k)
    pieces = [sides(f, width) for f in frames]
    errors, swings, hidden = [], [], 0
    for label in labels:
        for side in (0, 1):
            offsets = [p.get(label, (None, None))[side] for p in pieces]
            rest = next((o for o in reversed(offsets) if o is not None), None)
            if rest is None:
                continue
            previous = None
            for k in sorted(moving):
                if not 0 <= k < len(frames) or not series[label][k]:
                    previous = None
                    continue
                edge = series[label][k][side]
                if not 1 < edge < width - 1 or covered(k, label, side):
                    previous = None
                    continue
                if offsets[k] is None:
                    hidden += 1
                    previous = None
                    continue
                error = offsets[k] - rest
                errors.append(abs(error))
                if previous is not None:
                    swings.append(abs(error - previous))
                previous = error
    mean = lambda values: sum(values) / len(values) if values else 0  # noqa: E731
    return dict(pjit=mean(jitter), pstall=stalls, ptorn=len(torn), pgap=gap,
                pjitm=mean(kinds[0]["jitter"]), pstallm=kinds[0]["stalls"], pjits=mean(kinds[1]["jitter"]), pstalls=kinds[1]["stalls"],
                pslip=slips, pfreeze=sum(1 for n, c in zip(under_way, changed) if n and not c),
                plat=first_change * 1000 / FPS if first_change is not None else 0,
                pdur=(last_change + 1) * 1000 / FPS if last_change is not None else 0,
                pbord=sum(errors) / len(errors) if errors else 0, pbmax=max(errors, default=0),
                pbjit=sum(swings) / len(swings) if swings else 0, pbhid=hidden,
                pstray=sum(1 for f in frames if f["stray"] >= 6), pborders=any(f["b"] for f in frames))


if __name__ == "__main__":
    data = extract(Path(sys.argv[1]))
    print(f"{len(data['frames'])} frames, {sum(1 for f in data['frames'] if f['w'])} with test windows, "
          f"{sum(1 for f in data['frames'] if f['stray'] >= 6)} with border colour where none belongs")
