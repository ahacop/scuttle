# Animation harness

Records scuttle animating three test windows and measures how smooth it was.

```sh
APP=$PWD/build/scuttle.app scripts/anim/bench.sh /tmp/anim/mine 3
```

`bench.sh` runs `run.sh` several times and prints each measure's mean and range. `run.sh` on its own makes one
recording and prints a table per command. Each run takes over the screen for about 20 seconds on workspace 5,
which must be empty, and returns to the workspace it started on. Don't touch the mouse or keyboard meanwhile.

- `animtest.swift`: the test app. Windows of a solid colour with stripes and their width written in them, logging
  every draw. It can be made less obliging than a plain window: see the profiles below.
- `animbench.swift`: sends the scenario's commands through scuttle's socket and samples the window server's frame
  of every test window, and of each of scuttle's border pieces under its own id, every 4 ms or so.
- `scenario.txt`: what to do: preset widths, maximize, a second command while the first still glides, focus, move,
  and opening a fourth window (`open <label> <colour>`).
- `config.py`: the config scuttle records with: yours, with border colours nothing else on screen has, gaps wide
  enough to keep neighbours' borders apart, and the `resize` setting of the run.
- `analyze.py`: measures for each command. From the trace, on a 60 Hz grid: stalls (frames where a moving edge
  stands still), reversals, torn frames (neighbours' gap off by more than 4 points), the worst gap, update rate,
  stale content, duration. From `borders.py`, every border piece against the window it belongs to, on all four
  sides: how far off, how much that swings, and pieces astray, missing or unsettled. From `pixels.py`, the same
  questions asked of the recording, frame by frame as the display showed them (the `p` measures). `compare.py`
  summarizes several runs.
- `sheet.py`: the frames of each command side by side in one picture, to look at.

## What to trust

The trace is where the window server had each window when asked. The recording is what the display showed. They
differ: a pushed window that the trace has moving on every sample can show the same place for two frames and then
jump, and a border the trace has within a few points of its window can be hidden under the neighbour on screen.
When they disagree, the `p` measures are right. And look: `sheet.py <run> --top` puts sixteen frames of the top of
the screen one under the other, and a border drawn in the menu bar is plain there when no measure was written to
look for it. A measure only finds what someone thought to ask; before calling a change better, look at its frames.

Some things are bugs, not numbers, and fail a check whatever the build compared with does: a border piece somewhere
its window never asked it to be (`stray`, `pstray`), one off its window once the window has stopped (`unsettled`),
one left against no window (`orphans`).

## Kinds of window

A window that does all it is asked at once flatters a change that leans on that. `PROFILE` picks what the test
windows are like, and `RESIZE` the `[animations] resize` setting (`glide` or `instant`):

- `ideal`: three apps, one window each, drawn at once.
- `slow`: each redraw takes 25 ms, so a new size shows late and writes queue up behind it.
- `grid`: the first window only takes widths in steps of 120 points, as a terminal does.
- `minimum`: the first window refuses to be narrower than 40% of the screen.
- `shared`: the three windows belong to one app, which takes their frames one after another.

`ab.sh` and `check.sh` take them as `CONDITIONS="ideal:glide slow:glide ..."`. A change is better only if it is no
worse under any of them.

With `APP` set, scuttle is restarted from that bundle with its logs on: `SCUTTLE_ANIM_LOG` (each animation step's
timing and frames), `SCUTTLE_BORDER_LOG` (border work), `SCUTTLE_AX_LOG` (each Accessibility write) and
`SCUTTLE_EVENT_LOG` (each window-server event: how long it waited for the main thread and how long handling it
took). From them the analysis adds what the animation cost scuttle itself: the frame loop's rate, the border work,
the events by kind, the share of the animations' time the main thread was busy with all of that, and the
Accessibility writes by kind. The measures above say what the screen showed; these say where to look when it was
bad. A stall the logs don't explain is best found with `sample scuttle 12 -file out.txt` during a run: that is how
a window-server call on a background queue was found holding the main thread for half a second at a time.

`APP_ENV` passes more to `open`, such as `APP_ENV="--env SCUTTLE_NO_BORDER_TRACKING=1"` to compare without border
tracking.

Runs vary with whatever else the Mac is doing, sometimes more than a change being measured. To compare builds or
settings, alternate them in one session (A, B, A, B, ...) rather than benching one and then the other. `ab.sh` does
that for any number of them and prints each one's measures:

```sh
scripts/anim/ab.sh /tmp/anim/ab 3 base=build/ab/base/scuttle.app head=build/scuttle.app \
  "untracked=build/scuttle.app::--env SCUTTLE_NO_BORDER_TRACKING=1"
```

Build each bundle with `IDENTITY=<your Developer ID hash> scripts/bundle.sh` so the Accessibility permission carries
over, and copy it aside (`ditto build/scuttle.app build/ab/base/scuttle.app`) before building the next. Don't build
while a run records: the compiler takes the frames being measured.

## Regression checks

Two layers keep animations from getting worse:

- `Tests/ScuttleAppTests/AnimationSmoothnessTests.swift`, part of `swift test` and CI. They step the real Animator
  with a test clock instead of a display link and check the frames it asks for: every moving window gets a frame
  on every tick, in one batch; the ease ends on time, also after a second command mid-flight; edges never turn
  back; neighbouring columns keep their gap; a step of 40 windows stays far under a display frame. They don't see
  apps or the window server. `scripts/tests/test_anim_check.py` checks this harness's own measures on made-up traces.
- `just anim-check [runs]` (`check.sh`), on your Mac. It bundles this build and downloads the latest release into
  `build/anim-baseline/`, records each `runs` times (default 3) under each of six conditions, alternating, and
  compares the medians with `check.py`. A release from before `SCUTTLE_CONFIG` draws its borders in your colours,
  which the recording can't be read by, so the borders' `p` measures are only shown against it. A measure fails when this build is worse by more than both a share of the release's value and a fixed
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
