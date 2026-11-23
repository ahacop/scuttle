#!/usr/bin/env python3
"""Lays out the frames of each command of a recording side by side, to look at what the measures can't say.

For every command of a run that moved a window, `sheet-<n>-<command>.png` in the run directory: the 16 display
frames from just before the command took effect, 4 by 4, read left to right. `--top` keeps only the top of the
screen at full size, where the menu bar and the windows' top borders are, instead of the whole screen scaled down.

Usage: sheet.py <run dir> [--top] [command numbers...]
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402


def main():
    run = Path(sys.argv[1])
    top = "--top" in sys.argv
    wanted = {int(a) for a in sys.argv[2:] if a.isdigit()}
    events, trace, _, _ = analyze.load(run)
    video = analyze.recording(run, trace, sorted(trace))
    if not video:
        sys.exit("no recording to read, or it could not be matched to the trace")
    data, frame_of = video
    rows = analyze.analyze(run)
    for n, (t0, command) in enumerate(events):
        if (wanted and n not in wanted) or n >= len(rows) or not rows[n]["states"]:
            continue
        first = max(frame_of(t0), 0)
        crop = "crop=iw/2:120:0:0," if top else "scale=960:-1,"
        out = run / f"sheet-{n}-{command.split()[0]}{'-top' if top else ''}.png"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(run / "screen.mp4"), "-vf",
                        f"select='between(n,{first},{first + 15})',{crop}tile={'1x16' if top else '4x4'}", "-frames:v", "1", str(out)], check=True)
        print(out)


if __name__ == "__main__":
    main()
