# Animation harness

Records scuttle animating three test windows and measures how smooth it was.

```sh
APP=$PWD/build/scuttle.app scripts/anim/bench.sh /tmp/anim/mine 3
```

`bench.sh` runs `run.sh` several times and prints each measure's mean and range. `run.sh` on its own makes one
recording and prints a table per command. Each run takes over the screen for about 15 seconds on workspace 5,
which must be empty, and returns to the workspace it started on. Don't touch the mouse or keyboard meanwhile.

- `animtest.swift`: the test app. One window of a solid colour with stripes and its width written in it, logging
  every draw.
- `animbench.swift`: sends the scenario's commands through scuttle's socket and samples the window server's frame
  of every test window, and of scuttle's border pieces, every 4 ms or so.
- `scenario.txt`: what to do: preset widths, maximize, focus, move, and opening a fourth window (`open <label> <colour>`).
- `analyze.py`: measures for each command, on a 60 Hz grid: stalls (frames where a moving edge stands still),
  reversals, torn frames (neighbours' gap off by more than 4 points), the worst gap, update rate, stale content,
  duration, and border lag (how far each moving window's top border piece is from its edges). `compare.py`
  summarizes several runs.

With `APP` set, scuttle is restarted from that bundle with its logs on: `SCUTTLE_ANIM_LOG` (each animation step's
timing and frames), `SCUTTLE_BORDER_LOG` (border work) and `SCUTTLE_AX_LOG` (each Accessibility write). The
analysis adds the frame loop's rate and the border work's cost when they are there. `APP_ENV` passes more to
`open`, such as `APP_ENV="--env SCUTTLE_NO_BORDER_TRACKING=1"` to compare without border tracking.

Runs vary with whatever else the Mac is doing, sometimes more than a change being measured. To compare two
builds or settings, alternate them in one session (A, B, A, B, ...) rather than benching one and then the other. Build the bundle with
`IDENTITY=<your Developer ID hash> scripts/bundle.sh` so the Accessibility permission carries over.

## Regression checks

Two layers keep animations from getting worse:

- `Tests/ScuttleAppTests/AnimationSmoothnessTests.swift`, part of `swift test` and CI. They step the real Animator
  with a test clock instead of a display link and check the frames it asks for: every moving window gets a frame
  on every tick, in one batch; the ease ends on time, also after a second command mid-flight; edges never turn
  back; neighbouring columns keep their gap; a step of 40 windows stays far under a display frame. They don't see
  apps or the window server. `scripts/tests/test_anim_check.py` checks this harness's own measures on made-up traces.
- `just anim-check [runs]` (`check.sh`), on your Mac. It bundles this build and downloads the latest release into
  `build/anim-baseline/`, records each `runs` times (default 5), alternating, and compares the medians with
  `check.py`. A measure fails when this build is worse by more than both a share of the release's value and a fixed
  amount (the limits are at the top of `check.py`). It exits non-zero on failure, and `scripts/release.sh` runs
  it before preparing a release (`SKIP_ANIM_CHECK=1` skips it). Afterwards the scuttle that was running is started
  again. Set `BASE_APP` or `HEAD_APP` to compare other bundles, such as a branch against main.

GitHub's macOS runners have no display to record and no Accessibility permission, so the second layer can't run
in CI.

Needs ffmpeg (`brew install ffmpeg`) and Screen Recording permission for the terminal running it. The recording
is `screen.mp4` in each run directory; to look at frames:

```sh
ffmpeg -ss 1.2 -i run1/screen.mp4 -vf "crop=1300:500:1500:500,scale=325:125,tile=4x6" -frames:v 1 sheet.png
```
