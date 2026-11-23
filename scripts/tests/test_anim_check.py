"""The animation measures of scripts/anim on made-up traces, and check.py's pass/fail rule."""
import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "anim"))
from analyze import analyze  # noqa: E402
from check import LIMITS, check  # noqa: E402

FRAME = 1 / 60


def ease(u):
    return 3 * u * u - 2 * u * u * u


def write_run(run, lag=0, stall=None):
    """Column A widens from 600 to 900 over 12 frames while B, 10 points right of it, makes room. B's frames are
    `lag` frames late; with `stall`, A skips that frame."""
    run.mkdir(parents=True, exist_ok=True)
    with open(run / "events.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time", "command", "reply"])
        w.writerow([1.0, "switch-preset-column-width", "ok"])
        w.writerow([2.0, "end", "ok"])
    with open(run / "trace.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time", "label", "x", "y", "width", "height"])
        for k in range(-2, 40):
            t = 1.0 + (k + 0.5) * FRAME
            ka = k - 1 if stall is not None and k == stall else k
            ua, ub = (min(max(n / 12, 0), 1) for n in (ka, k - lag))
            width = round(600 + 300 * ease(ua))
            w.writerow([t, "A", 10, 40, width, 1000])
            w.writerow([t, "B", round(620 + 300 * ease(ub)), 40, 600, 1000])


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


class CheckTests(unittest.TestCase):
    base = dict(torn=10, stalls=85, reversals=1, hz=55, ms=220, stale=0.15, border=63, bfar=0.35)

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
        self.assertEqual(set(LIMITS), set(self.base))


if __name__ == "__main__":
    unittest.main()
