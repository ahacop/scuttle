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
- `switch.py`: for a scenario's `activate` lines, where no window of the trace moves and the whole screen changes:
  how long after the command the screen first changed, for how many frames, and where the full-screen window's
  edge was on each of them. A cut is one frame, 0 to 100; a slide counts across evenly. Run by run.sh after
  analyze.py; `switch-<n>-<label>.png` are its frames.
- `table.py`: `ab.sh`'s runs side by side, a row per build under each condition, and with `--commands` per
  command: a change can help one kind of command and hurt another, which a run's totals hide.
- `animcal.swift`, `cal.sh`, `cal.py`: calibration. See below.
- `awake.sh`: sourced by every script that records. It keeps the display awake while the script runs and refuses
  to start with the screen locked: a display asleep fires no display link, so nothing animates.

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

The measures are also split by what was asked of a window: `pjitm` and `pstallm` for windows only moved, `pjits`
and `pstalls` for windows resized, whose apps must draw before a step shows. `pslip` counts stalls never made up
for (the window is a frame later from then on) and `pfreeze` frames on which nothing on its way moved at all, which
is the display or the window server, not one app. `plat` and `pdur` are the milliseconds from a command to the
first and the last frame that moved. A change of a few points long after a glide stopped (a shadow or a border
settling) is left out, or the still frames before it would count as stalls.

A window that opens is measured from scuttle's first step, not from the command. The scenario's new window is a
new process: it shows some 160 ms after the command, macOS zooms it open for another 90 ms, a point or two a
frame, and only then does its app answer Accessibility, so scuttle's glide starts some 250 ms after the command
however fast scuttle is. That wait is `pwait`; counted in, the zoom read as fifteen to thirty stalls. While it
waits for the app's first answer (`axWindow` in `classify`, 55 to 95 ms) scuttle's main thread is held, which
nothing on screen shows as long as no other window is animating.

## Scenarios

`scenario.txt`, the default, is width presets, maximize, a retarget mid-glide, a column swap and a window opening.
`scenario-more.txt` is the rest of what scuttle animates on one display: the strip scrolling as focus moves to a
column out of view, `resize width` in small steps and three in a row, `balance-sizes`, `fullscreen` on and off,
`layout floating` and `tiling`, a window closing, and the mouse dragging a window's edge and dragging a window
onto another column. `scenario-swap.txt` is the column swap alone, six times, for quick rounds on the command
that stutters most. `scenario-fullscreen.txt` is the one thing here that isn't windows moving: switching between
the tiled workspace and a window in macOS's native full screen by activating apps, as Cmd-Tab does. It needs
`FULLSCREEN=1`, which has run.sh add a fourth window, F, in full screen; `WORKSPACE=<n>` puts the tiled test
windows on that workspace instead of 5, which leaves the Spaces of the workspaces after it between them and F.
`switch.py` measures it. Give one as run.sh's second argument, or as `SCENARIO=scripts/anim/scenario-more.txt` to
ab.sh, bench.sh and check.sh. The drags move the real pointer and press its button.

Every column is as tall as the display and holds one window, so there are no heights to test; macOS full screen
is not a layout of scuttle's, and only the switch to and from it is recorded. Not covered: a second display, other refresh rates, and real apps.

## Calibration

`scripts/anim/cal.sh <out dir> [kind...]` records glides whose smoothness is known, with scuttle stopped, and
`cal.py` reads them as `pixels.py` reads a run:

- `layer`: a layer the render server animates. It scores no stalls, so a stall in a run is not the recording's.
- `window[:delay ms]`: a window that moves itself on every display frame. No stalls either.
- `ax[:delay ms[:move|size|both|first|same[:draw ms]]]`: a window of another process moved through Accessibility on
  every display frame, as scuttle moves windows, `delay` ms into the frame. This is the floor for scuttle.

What it showed, on a 60 Hz display: a move written at the very start of a frame is as smooth as the window moving
itself. Written 1 to 16 ms into the frame, it loses about one frame per glide: the display shows one frame twice
and everything after it a frame later. So where in the frame the writes land matters more than how many there are,
and an app that is busy drawing when the frame starts, because its window is being resized, answers late and
lands anywhere.

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

How steps are timed and written is set through the environment too, so one bundle can be recorded against itself
(`Sources/scuttle/AnimationTuning.swift`). On by default, each with a way back to compare against:
`SCUTTLE_SNAP_RESIZE_WITHIN` (a size changing by no more than that many points is taken at once; 16, and 0 glides
every size) and `SCUTTLE_STEP_WRITES` (a step writes only the position or size that changed; `all` writes size,
position, size to every resized window). Off by default, having shown no gain on screen: `SCUTTLE_STEP_DELAY_MS`
(step that long into the frame; helps the shared profile, hurts the others), `SCUTTLE_ALIGN_START=1` (skip a
display link's first tick when it comes mid-frame) and `SCUTTLE_RESIZE_LEAD` (frames ahead a gliding size is asked).

More switches, each back to how it was before, for comparing: `SCUTTLE_TRACK_DELAY` (how far into a frame the
borders of moving windows are placed, as a share of it: 0.5, and 0 for the start of the frame),
`SCUTTLE_BORDER_STRETCH=0` (a border is reshaped and redrawn for every new width of its window instead of having
its runs stretched), `SCUTTLE_BORDER_RECOLOR=0` (a border that only changes colour is reshaped and placed again) and
`SCUTTLE_FOCUS_SHARE=0` (the trees and the borders each ask the window server for the focused window).

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
