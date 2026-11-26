#!/usr/bin/env python3
"""Measures what the display showed when an app was activated on another Space: the `activate` lines of a scenario,
such as a switch between a tiled workspace and an app in macOS's native full screen.

No window of the trace moves in such a switch, so this reads the whole screen: every frame of the recording scaled
down to 96 by 54 grey pixels, and for each frame how much of the screen differs from the frame before it and from
the frame the switch ends on. For each `activate`:

- wait: milliseconds from the command to the first frame that changed
- ms: from that frame to the last one that changed, within 1.5 s of the command
- frames: how many frames changed in between. A cut is 1: one frame shows the old Space and the next the new one
- slide: where the left edge of F, run.sh's window in full screen, was on each of those frames, as a share of the
  screen's width: 0 with F filling the screen, 100 with it gone. A slide counts evenly from one to the other; a
  cut reads 0 100

and `switch-<n>-<label>.png` in the run directory: the 24 frames from two before the first change, 6 by 4.

Usage: switch.py <run dir> [--json]
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402

W, H = 96, 54
CHANGED = 0.004  # the share of the screen that must differ for a frame to count as changed: more than a clock's digit
DIFFERS = 24     # how far apart two grey values are when a pixel differs
WINDOW = 1.5     # seconds after the command in which the switch is looked for


def frames_of(run):
    # At a steady 60 a second, as pixels.py's are: the recording leaves a frame out here and there.
    video = subprocess.run(["ffmpeg", "-v", "error", "-i", str(run / "screen.mp4"), "-vf", f"fps=60,scale={W}:{H},format=gray",
                            "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    return [video[i:i + W * H] for i in range(0, len(video) - W * H + 1, W * H)]


def differing(a, b):
    """The share of the screen on which two frames differ."""
    return sum(abs(x - y) > DIFFERS for x, y in zip(a, b)) / (W * H)


def measure(frames, first, readings, fps=60):
    """`first`: the frame the command fell in; `readings`: pixels.py's. None if nothing on screen changed."""
    last = min(first + int(WINDOW * fps), len(frames) - 1)
    changed = [k for k in range(first + 1, last + 1) if differing(frames[k - 1], frames[k]) > CHANGED]
    if not changed:
        return None
    width = readings["width"]
    steps = [round(100 * readings["frames"][k]["w"].get("F", [width])[0] / width)
             for k in range(changed[0] - 1, min(changed[-1] + 1, len(readings["frames"])))]
    return dict(wait=round((changed[0] - first) * 1000 / fps), ms=round((changed[-1] - changed[0] + 1) * 1000 / fps),
                frames=len(changed), slide=steps, at=changed[0])


def main():
    run = Path(sys.argv[1])
    events, trace, _, _ = analyze.load(run)
    video = analyze.recording(run, trace, sorted(trace))
    if not video:
        sys.exit("no recording to read, or it could not be matched to the trace")
    frames = frames_of(run)
    rows = []
    for n, (t0, command) in enumerate(events):
        if not command.startswith("activate "):
            continue
        row = measure(frames, max(video[1](t0), 0), video[0]) or dict(wait=None, ms=0, frames=0, slide=[], at=None)
        row.update(n=n, command=command)
        rows.append(row)
        if row["at"] is not None:
            out = run / f"switch-{n}-{command.split()[1]}.png"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(run / "screen.mp4"), "-vf",
                            f"fps=60,select='between(n,{row['at'] - 2},{row['at'] + 21})',scale=640:-1,tile=6x4", "-frames:v", "1", str(out)], check=True)
    if "--json" in sys.argv:
        return print(json.dumps(rows))
    print(f"{'command':<14}{'wait':>6}{'ms':>6}{'frames':>8}  slide (F's left edge; % of the screen's width)")
    for r in rows:
        wait = "-" if r["wait"] is None else r["wait"]
        print(f"{r['command']:<14}{wait:>6}{r['ms']:>6}{r['frames']:>8}  {' '.join(map(str, r['slide']))}")


if __name__ == "__main__":
    main()
