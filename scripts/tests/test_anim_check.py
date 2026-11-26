"""The animation measures of scripts/anim on made-up traces, and check.py's pass/fail rule."""
import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "anim"))
import pixels  # noqa: E402
from analyze import analyze  # noqa: E402
from check import ABSOLUTE, LIMITS, check  # noqa: E402
import switch  # noqa: E402

FRAME = 1 / 60


def ease(u):
    return 3 * u * u - 2 * u * u * u


def write_run(run, lag=0, stall=None, border=None, runs=False):
    """Column A widens from 600 to 900 over 12 frames while B, 10 points right of it, makes room. B's frames are
    `lag` frames late; with `stall`, A skips that frame. `border` gives A a border 4 points wide, its four pieces under
    ids 1-4 (top, bottom, left, right): `(late, corner, hidden, short)`, the frames the pieces trail A by, the
    frames at which the top piece sits in the corner of the screen, those at which it is not on screen, and how far
    short of A's final width the border stops. With `runs` the pieces are as scuttle draws them after
    0.5: runs along the top and the bottom, and sides 20 points wide that carry the corners."""
    run.mkdir(parents=True, exist_ok=True)
    with open(run / "events.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time", "command", "reply"])
        w.writerow([1.0, "switch-preset-column-width", "ok"])
        w.writerow([2.0, "end", "ok"])
    with open(run / "trace.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time", "label", "x", "y", "width", "height", "id"])
        for k in range(-2, 70):
            t = 1.0 + (k + 0.5) * FRAME
            ka = k - 1 if stall is not None and k == stall else k
            ua, ub = (min(max(n / 12, 0), 1) for n in (ka, k - lag))
            width = round(600 + 300 * ease(ua))
            w.writerow([t, "A", 10, 40, width, 1000, 100])
            w.writerow([t, "B", round(620 + 300 * ease(ub)), 40, 600, 1000, 101])
            if border is None:
                continue
            late, corner, hidden, short = border
            around = round(600 + 300 * ease(min(max((k - late) / 12, 0), 1))) - (short if k - late >= 12 else 0)
            if runs:
                top = [0, 0, around - 32, 4] if k in corner else [26, 36, around - 32, 4]
                if k not in hidden:
                    w.writerow([t, "border", *top, 1])
                w.writerow([t, "border", 26, 1040, around - 32, 4, 2])
                w.writerow([t, "border", 6, 36, 20, 1008, 3])
                w.writerow([t, "border", around - 6, 36, 20, 1008, 4])
                continue
            top = [0, 0, around + 8, 20] if k in corner else [6, 36, around + 8, 20]
            if k not in hidden:
                w.writerow([t, "border", *top, 1])
            w.writerow([t, "border", 6, 1024, around + 8, 20, 2])
            w.writerow([t, "border", 6, 56, 4, 968, 3])
            w.writerow([t, "border", 10 + around, 56, 4, 968, 4])


class MeasureTests(unittest.TestCase):
    def measure(self, **kwargs):
        with tempfile.TemporaryDirectory() as d:
            write_run(Path(d), **kwargs)
            return analyze(Path(d))[0]

    def test_columns_moving_together_are_not_torn(self):
        row = self.measure()
        self.assertEqual(row["torn"], 0)
        self.assertEqual(row["stalls"], 0)
        self.assertEqual(row["reversals"], 0)
        self.assertAlmostEqual(row["ms"], 12 * FRAME * 1000, delta=FRAME * 1000)

    def test_a_neighbour_a_frame_late_is_torn(self):
        self.assertGreaterEqual(self.measure(lag=1)["torn"], 8)

    def test_a_skipped_frame_is_a_stall(self):
        self.assertGreaterEqual(self.measure(stall=6)["stalls"], 1)


class BorderTests(unittest.TestCase):
    runs = False

    def measure(self, late=0, corner=(), hidden=(), short=0):
        with tempfile.TemporaryDirectory() as d:
            write_run(Path(d), border=(late, corner, hidden, short), runs=self.runs)
            return analyze(Path(d))[0]

    def test_a_border_on_its_window_is_clean(self):
        row = self.measure()
        for measure in ("border", "bmax", "bjit", "stray", "missing", "unsettled", "orphans"):
            self.assertEqual(row[measure], 0, measure)

    def test_a_border_a_frame_late_is_off_but_not_astray(self):
        row = self.measure(late=1)
        self.assertGreater(row["border"], 5)
        self.assertGreater(row["bmax"], 30)
        self.assertEqual((row["stray"], row["missing"], row["unsettled"]), (0, 0, 0))

    def test_a_piece_in_the_corner_of_the_screen_is_astray(self):
        self.assertEqual(self.measure(corner=(4, 5, 9))["stray"], 3)

    def test_a_piece_gone_while_its_window_moves_is_missing(self):
        self.assertEqual(self.measure(hidden=(3, 4))["missing"], 2)

    def test_a_border_that_stops_short_is_unsettled(self):
        self.assertGreaterEqual(self.measure(short=6)["unsettled"], 1)

    def test_a_border_swinging_about_its_window_jitters_more_than_one_trailing_it(self):
        self.assertGreater(self.measure(late=1)["bjit"], 0)
        self.assertEqual(self.measure()["bjit"], 0)


class RunBorderTests(BorderTests):
    """The same measures of a border whose sides carry the corners, with runs between them."""
    runs = True


class PixelTests(unittest.TestCase):
    """pixels.py on made-up frames: A widens from 600 to 900 while B makes room, each with side pieces 4 points wide."""

    def frames(self, late=0, repeat=None, behind=0):
        frames = []
        for k in range(-3, 20):
            ka = k - 1 if k == repeat else k
            width = 600 + 300 * ease(min(max(ka / 12, 0), 1))
            pushed = 600 + 300 * ease(min(max((k - behind) / 12, 0), 1))
            around = 600 + 300 * ease(min(max((ka - late) / 12, 0), 1))
            a, b = [10, 10 + width], [26 + pushed, 626 + pushed]
            runs = [[6, 10, 0], [10 + around, 14 + around, 0], [b[0] - 4, b[0], 1], [b[1], b[1] + 4, 1]]
            # Borders are drawn below the windows: a piece under one doesn't show.
            runs = [r for r in runs if not any(lo < r[1] and r[0] < hi for lo, hi in (a, b))]
            frames.append(dict(w={"A": a, "B": b}, stray=0, b=runs))
        return dict(frames=frames, width=3840)

    def measure(self, **kwargs):
        data = self.frames(**kwargs)
        return pixels.measure(data, 0, len(data["frames"]))

    def test_a_smooth_glide_with_its_border_on(self):
        row = self.measure()
        self.assertLess(row["pjit"], 4)
        self.assertEqual((row["pstall"], row["ptorn"], row["pbhid"], row["pstray"]), (0, 0, 0, 0))
        self.assertLess(row["pbord"], 0.5)

    def test_a_point_settling_long_after_the_glide_is_not_the_glide(self):
        data = self.frames()
        last = data["frames"][-1]
        for k in range(40):
            data["frames"].append(dict(last, w={"A": list(last["w"]["A"]), "B": [last["w"]["B"][0], last["w"]["B"][1] + (k >= 30)]}))
        row = pixels.measure(data, 0, len(data["frames"]))
        self.assertEqual((row["pstall"], row["pfreeze"]), (0, 0))
        self.assertLess(row["pdur"], 400)

    def test_a_frame_shown_twice_jitters_and_stalls(self):
        smooth, repeated = self.measure(), self.measure(repeat=6)
        self.assertGreaterEqual(repeated["pstall"], 1)
        self.assertGreater(repeated["pjit"], smooth["pjit"] * 1.5)

    def test_measures_are_split_by_whether_the_window_was_resized(self):
        row = self.measure(repeat=6)
        # A widens, B is only pushed; the frame shown twice is A's.
        self.assertGreaterEqual(row["pstalls"], 1)
        self.assertEqual(row["pstallm"], 0)
        self.assertGreater(row["pjits"], row["pjitm"])

    def test_a_stall_made_up_for_is_not_a_slip_and_one_never_made_up_for_is(self):
        self.assertEqual(self.measure(repeat=6)["pslip"], 0)
        late = self.frames()
        # From the seventh frame on, everything is shown a frame later.
        late["frames"] = late["frames"][:9] + [late["frames"][8]] + late["frames"][9:]
        row = pixels.measure(late, 0, len(late["frames"]))
        self.assertGreaterEqual(row["pslip"], 2)
        self.assertEqual(row["pfreeze"], 1)

    def test_latency_is_from_the_command_to_the_first_frame_that_moves(self):
        row = self.measure()
        self.assertAlmostEqual(row["plat"], 4 * 1000 / 60, delta=1)
        self.assertGreater(row["pdur"], row["plat"] + 150)

    def test_a_neighbour_a_frame_behind_tears_the_gap(self):
        self.assertGreaterEqual(self.measure(behind=1)["ptorn"], 6)

    def test_a_border_a_frame_late_is_under_its_growing_window(self):
        # Drawn below its window, the piece on the side the window grows towards is covered by it.
        self.assertGreaterEqual(self.measure(late=1)["pbhid"], 8)

    def test_a_border_a_frame_ahead_is_under_the_neighbour(self):
        self.assertGreaterEqual(self.measure(late=-1)["pbhid"], 6)

    def test_a_border_a_little_ahead_shows_off_its_window(self):
        row, on = self.measure(late=-0.25), self.measure()
        self.assertGreater(row["pbord"], on["pbord"] + 1)
        self.assertGreater(row["pbmax"], 5)

    def test_border_colour_in_the_menu_bar_is_astray(self):
        data = self.frames()
        data["frames"][5]["stray"] = 40
        self.assertEqual(pixels.measure(data, 0, len(data["frames"]))["pstray"], 1)

    def test_a_window_is_the_longest_stretch_of_its_colour(self):
        fill, other = pixels.rgb(pixels.FILLS["A"]), (30, 30, 30)
        row = bytes(c for x in range(600) for c in (fill if 100 <= x < 120 or 200 <= x < 500 else other))
        spans, _ = pixels.read_row(row, 600, pixels.window_classifier(), [lambda *_: False] * 2)
        self.assertEqual(spans, {"A": [200, 500]})


class CheckTests(unittest.TestCase):
    base = dict(torn=10, stalls=85, reversals=1, hz=55, ms=220, stale=0.15, border=63, bfar=0.35, bjit=20, missing=4,
                pjit=6, pstall=20, ptorn=10, pbord=30, pbjit=15, pbhid=4, stray=0, unsettled=0, orphans=0, pstray=0)

    def failed(self, **head):
        return {r["measure"] for r in check(self.base, {**self.base, **head}) if r["failed"]}

    def test_the_same_numbers_pass(self):
        self.assertEqual(self.failed(), set())

    def test_noise_within_the_limits_passes(self):
        self.assertEqual(self.failed(torn=13, stalls=100, hz=52, ms=240, border=70), set())

    def test_clearly_worse_fails(self):
        self.assertEqual(self.failed(torn=31, hz=39, ms=410, border=139), {"torn", "hz", "ms", "border"})

    def test_better_passes(self):
        self.assertEqual(self.failed(torn=0, stalls=0, hz=60, ms=200, border=0, bfar=0), set())

    def test_a_measure_near_zero_has_a_fixed_allowance(self):
        base = {**self.base, "torn": 0}
        self.assertEqual({r["measure"] for r in check(base, {**base, "torn": 3}) if r["failed"]}, set())
        self.assertEqual({r["measure"] for r in check(base, {**base, "torn": 4}) if r["failed"]}, {"torn"})

    def test_bfar_is_only_shown(self):
        self.assertEqual(self.failed(bfar=0.9), set())

    def test_every_summary_measure_has_a_limit(self):
        self.assertEqual(set(LIMITS) | set(ABSOLUTE), set(self.base))

    def test_what_must_not_happen_fails_even_when_the_base_does_it(self):
        base = {**self.base, "stray": 5, "pstray": 2}
        failed = {r["measure"] for r in check(base, {**base, "stray": 1, "pstray": 1}) if r["failed"]}
        self.assertEqual(failed, {"stray", "pstray"})

    def test_recorded_borders_are_not_held_to_a_base_that_shows_none(self):
        base = {**self.base, "pborders": False, "pbord": 0, "pbhid": 90}
        failed = {r["measure"] for r in check(base, {**self.base, "pborders": True, "pbord": 30}) if r["failed"]}
        self.assertEqual(failed, set())


class SwitchTests(unittest.TestCase):
    """switch.py on made-up screens: F, dark, gives way to a light workspace from the left."""

    def screens(self, shares):
        """A grey frame and a reading for each share of the screen the workspace has taken."""
        frames, readings = [], []
        for share in shares:
            edge = round(share * switch.W)
            frames.append((bytes([220]) * edge + bytes([40]) * (switch.W - edge)) * switch.H)
            readings.append(dict(w={"F": [share * 1000, 1000]} if share < 1 else {}))
        return frames, dict(frames=readings, width=1000)

    def test_a_cut_is_one_frame(self):
        frames, readings = self.screens([0] * 20 + [1] * 100)
        row = switch.measure(frames, 2, readings)
        self.assertEqual((row["wait"], row["ms"], row["frames"], row["slide"]), (300, 17, 1, [0, 100]))

    def test_a_slide_counts_across(self):
        frames, readings = self.screens([0] * 5 + [k / 10 for k in range(1, 11)] + [1] * 100)
        row = switch.measure(frames, 2, readings)
        self.assertEqual((row["wait"], row["ms"], row["frames"]), (50, 167, 10))
        self.assertEqual(row["slide"], [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100])

    def test_nothing_changing_is_no_switch(self):
        frames, readings = self.screens([0] * 120)
        self.assertIsNone(switch.measure(frames, 2, readings))


if __name__ == "__main__":
    unittest.main()
