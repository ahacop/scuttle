#!/usr/bin/env python3
"""What the recording makes of animcal's glides: for each kind, the frames a glide took, those on which the block
stood still (stall), and how far its edge was from the curve through its neighbours (jit, as pixels.py's pjit).
A layer animated by the render server is as smooth as the display gets, so what it scores is the recording's own
floor. Usage: cal.py <run dir>..."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from pixels import extract  # noqa: E402


def glides(xs):
    """Stretches of frames in which the edge moves, at least ten still frames apart."""
    moves = [k for k in range(1, len(xs)) if xs[k] is not None and xs[k - 1] is not None and abs(xs[k] - xs[k - 1]) >= 1]
    out, start = [], None
    for i, k in enumerate(moves):
        if start is None:
            start = k
        if i + 1 == len(moves) or moves[i + 1] - k > 10:
            if abs(xs[k] - xs[start - 1]) > 40:
                out.append((start, k))
            start = None
    return out


def measure(run, side=0):
    frames = extract(run)["frames"]
    xs = [f["w"]["A"][side] if "A" in f["w"] else None for f in frames]
    rows = []
    for start, end in glides(xs):
        stalls = sum(1 for k in range(start, end) if abs(xs[k] - xs[k - 1]) < 1)
        jitter = [abs(xs[k] - (-xs[k - 2] + 4 * xs[k - 1] + 4 * xs[k + 1] - xs[k + 2]) / 6)
                  for k in range(start + 1, end - 1) if None not in xs[k - 2:k + 3]]
        rows.append((end - start + 1, stalls, sum(jitter) / len(jitter) if jitter else 0))
    return rows


if __name__ == "__main__":
    print(f"{'run':34} {'glides':>6} {'frames':>6} {'stall':>6} {'jit':>6}   (means per glide; right edge after /)")
    for arg in sys.argv[1:]:
        run = Path(arg)
        cells = []
        for side in (0, 1):
            rows = measure(run, side)
            n = max(len(rows), 1)
            cells.append((len(rows), sum(r[0] for r in rows) / n, sum(r[1] for r in rows) / n, sum(r[2] for r in rows) / n))
        a, b = cells
        print(f"{run.name:34} {a[0]:6d} {a[1]:6.1f} {a[2]:6.2f} {a[3]:6.1f}   / {b[1]:5.1f} {b[2]:5.2f} {b[3]:5.1f}")
