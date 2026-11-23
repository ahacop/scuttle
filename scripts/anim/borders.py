"""Measures scuttle's focus borders against the windows they belong to, from run.sh's trace.

A border is four scuttle-owned windows, one per side. The trace gives each one's frame under its window id, so a
piece keeps its identity while it moves. At rest, when a command is sent and again when the next one is, every
piece is matched to the test window it lies against and each of its four edges to the window edge it is nearest.
Its outer edges belong the border's width outside the window and a side piece's inner edge on the window's edge,
wherever the window goes and whatever its size; only where the top and bottom pieces end and the side pieces begin
is read from the border as drawn. So a border drawn around a frame its window never took is off at rest too. For
every display frame of a command:

- error: how far, in points, a piece's worst edge is from where its window puts it
- stray: a piece edge outside everything its window asked of it during the command, by more than 24 points. A
  border that trails or leads its window is still somewhere the window has been or will be; one that is not has
  been put somewhere else, such as the corner of the screen
- missing: a piece its window had at the start that is not on screen while the window moves
- jitter: how much a piece's signed error changes from one frame to the next, in points: a border that trails its
  window steadily scores 0, one that jumps ahead and falls behind scores its swing
- unsettled: pieces off their window by more than a point and a half on the command's last frame
- orphans: pieces on screen at rest that lie against no test window
"""
import bisect

PAD = 8          # a piece lies against a window when its edges are within this, in all, of where that window's would be
STRAY = 24      # past everything its window asked of it by more than this, a piece is somewhere else
SETTLED = 1.5


def edges(rect):
    x, y, w, h = rect
    return (x, y, x + w, y + h)


def assign(piece, windows, width=4):
    """The window a piece lies against and, for each of its edges (left, top, right, bottom), the window edge it is
    anchored to and how far from it belongs, for a border `width` wide. `windows`: label -> rect. None when it lies
    against none: within PAD of where no window's border would have a piece."""
    pl, pt, pr, pb = edges(piece)
    best = None
    for label, rect in windows.items():
        wl, wt, wr, wb = edges(rect)
        if pr - pl <= 2 * width + 1:
            # A side piece: the border's width wide, outside the left edge or the right one, between the top and
            # bottom pieces, whose height is read from the border as drawn.
            for left in (True, False):
                anchors = [(0, -width), (1, pt - wt), (0, 0), (3, pb - wb)] if left else [(2, 0), (1, pt - wt), (2, width), (3, pb - wb)]
                want = expected(anchors, rect)
                off = abs(pl - want[0]) + abs(pr - want[2]) + (0 if wt - PAD <= pt and pb <= wb + PAD else 4 * PAD)
                if best is None or off < best[0]:
                    best = (off, label, anchors)
        else:
            # The top or the bottom piece: as wide as the window and the border on both sides, its outer edge outside.
            for top in (True, False):
                anchors = [(0, -width), (1, -width), (2, width), (1, pb - wt)] if top else [(0, -width), (3, pt - wb), (2, width), (3, width)]
                want = expected(anchors, rect)
                off = abs(pl - want[0]) + abs(pr - want[2]) + (abs(pt - want[1]) if top else abs(pb - want[3]))
                if best is None or off < best[0]:
                    best = (off, label, anchors)
    return (best[1], best[2]) if best and best[0] <= PAD else None


def expected(anchors, window):
    w = edges(window)
    return tuple(w[which] + offset for which, offset in anchors)


def measure(windows, pieces, times, grid, moving_until, width=4):
    """windows: label -> {sample time: rect}; pieces: id -> {sample time: rect}; times: every sample time, sorted;
    grid: the command's display frames; moving_until: the time the last window stopped. A command cut short by the
    next one, its windows still on their way at its last frame, has no rest to settle at: nothing is unsettled or
    orphaned then."""
    def sample(t):
        return times[max(bisect.bisect_right(times, t) - 1, 0)]

    def at(series, t):
        return series.get(sample(t))

    def rest(t):
        frames = {l: at(s, t) for l, s in windows.items()}
        frames = {l: r for l, r in frames.items() if r}
        found, orphans = {}, 0
        for pid, series in pieces.items():
            rect = at(series, t)
            if not rect:
                continue
            match = assign(rect, frames, width)
            if match:
                found[pid] = match
            else:
                orphans += 1
        return found, orphans

    start, _ = rest(grid[0])
    end, orphans = rest(grid[-1])
    at_rest = moving_until < grid[-1] - 0.1
    if not at_rest:
        orphans = 0

    # Where the command ends at rest, that is where a piece's place against its window is read: the start may be the
    # middle of the command before, cut short, with borders still on their way.
    owners = dict(start)
    if at_rest:
        owners.update(end)

    errors, swings, stray, missing, unsettled, worst = [], [], 0, 0, 0, 0.0
    for pid, (label, anchors) in owners.items():
        frames = [(at(pieces[pid], t), at(windows[label], t)) for t in grid]
        # Where the window was just before the command counts as asked too: its border may still be there.
        before = [at(windows[label], grid[0] - k / 60) for k in (1, 2, 3)]
        wants = [expected(anchors, w) for w in [w for _, w in frames] + before if w]
        if not wants:
            continue
        low = [min(w[i] for w in wants) - STRAY for i in range(4)]
        high = [max(w[i] for w in wants) + STRAY for i in range(4)]
        previous = None
        for t, (piece, window) in zip(grid, frames):
            if not window:
                previous = None
                continue
            if not piece:
                if pid in start and t <= moving_until:
                    missing += 1
                previous = None
                continue
            got, want = edges(piece), expected(anchors, window)
            signed = [g - w for g, w in zip(got, want)]
            if any(g < lo or g > hi for g, lo, hi in zip(got, low, high)):
                stray += 1
            if t <= moving_until + 0.05:
                error = max(abs(s) for s in signed)
                errors.append(error)
                worst = max(worst, error)
                if previous is not None:
                    swings.append(max(abs(a - b) for a, b in zip(signed, previous)))
            previous = signed
        last_piece, last_window = frames[-1]
        if at_rest and last_piece and last_window:
            off = max(abs(g - w) for g, w in zip(edges(last_piece), expected(anchors, last_window)))
            unsettled += off > SETTLED
    return dict(border=sum(errors) / len(errors) if errors else 0, bfar=sum(e > 4 for e in errors) / len(errors) if errors else 0,
                bmax=worst, bjit=sum(swings) / len(swings) if swings else 0, stray=stray, missing=missing,
                unsettled=unsettled, orphans=orphans, pieces=len(owners))
