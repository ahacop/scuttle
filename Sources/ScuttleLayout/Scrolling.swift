import CoreGraphics

// The scrolling layout, after niri's: a row of columns, one window each and as tall as the screen,
// each as wide as its own share of the screen whatever the number of columns, so the row runs past the
// screen edges and scrolls to keep the focused column in view. Columns that fit, a lone one too, start at the left
// outer gap, as niri lays them out, and focusing a column scrolls just far enough to show it whole.
//
// macOS cannot clip another app's window at the screen edge, so a window scrolled out of view is parked
// instead: on an edge with nothing beyond it, it hangs off the screen with `peek` points left on, in a gutter
// the columns keep an inner gap clear of; on an edge with another display beyond it, it stops flush at the
// border, behind the columns in view, so it never shows on the other display.

extension Workspace {
    /// How much of a parked window stays on screen. The WindowServer takes any position that leaves a little of
    /// a window on screen, but pulls one asked to go wholly off back until 40 points show.
    static let peek: CGFloat = 25

    /// Narrowest a column can be resized to, as a share of the screen.
    static let minimumColumnWidth = 0.1

    /// Put a window in a new column right of the focused one, at the default width.
    mutating func insertColumn(_ id: WindowID) {
        let index = focused.flatMap { columns.firstIndex(of: $0) }.map { $0 + 1 } ?? columns.count
        columns.insert(id, at: index)
        columnWidths[id] = columnWidth
    }

    /// The width of column `index` as a share.
    func width(ofColumn index: Int) -> Double { columnWidths[columns[index]] ?? columnWidth }

    /// Give column `index` the width `share`, kept between the narrowest a column goes and the whole screen.
    mutating func setWidth(ofColumn index: Int, _ share: Double) {
        columnWidths[columns[index]] = min(max(share, Self.minimumColumnWidth), 1)
    }

    /// Where the columns go: inside the outer gaps, and with more than one column also clear of the parked
    /// windows' gutter on each side without a wall, by half an inner gap, which with a column's own half makes
    /// a whole one. Column widths are shares of its width.
    var stripArea: CGRect {
        let area = gaps.inset(bounds)
        guard columns.count > 1 else { return area }
        let clear = Self.peek + gaps.horizontal / 2
        let left = walls.contains(.left) ? 0 : max(clear - gaps.left, 0)
        let right = walls.contains(.right) ? 0 : max(clear - gaps.right, 0)
        return CGRect(x: area.minX + left, y: area.minY, width: area.width - left - right, height: area.height)
    }

    /// Each column's start and width in points along the strip, from its left edge. Half an inner gap is part
    /// of a column on each side that has a neighbour, so neighbours end up a whole gap apart. Each column is its
    /// share of the screen, grown to fit its window's minimum width.
    func columnSpans(in area: CGRect) -> [(start: CGFloat, width: CGFloat)] {
        let count = columns.count, gap = gaps.horizontal
        var start: CGFloat = 0
        return columns.indices.map { i in
            let insets = (i > 0 ? gap / 2 : 0) + (i < count - 1 ? gap / 2 : 0)
            let minimum = minimumSizes[columns[i]]?.width ?? 0
            let width = max((area.width * CGFloat(width(ofColumn: i))).rounded(), minimum + insets)
            defer { start += width }
            return (start, width)
        }
    }

    /// The scroll offset the layout uses. The strip never scrolls past either end, and the column at an end
    /// reaches into the gutter there, which nothing is parked in, out to the outer gap. A strip that fits
    /// between the outer gaps starts at the left one, so changing a column's width never moves the first column.
    func offset(for spans: [(start: CGFloat, width: CGFloat)], in area: CGRect) -> CGFloat {
        let total = spans.last.map { $0.start + $0.width } ?? 0, inset = gaps.inset(bounds)
        let first = area.minX - inset.minX, last = total - area.width - (inset.maxX - area.maxX)
        guard first < last else { return first }
        return min(max(scrollOffset, first), last)
    }

    /// Scroll as little as shows the window's column whole, as Hyprland's `fit` does. A column wider than the
    /// screen is centred.
    mutating func reveal(_ id: WindowID) {
        guard let index = columns.firstIndex(of: id) else { return }
        let area = stripArea, spans = columnSpans(in: area), column = spans[index]
        let current = offset(for: spans, in: area)
        scrollOffset = column.width > area.width
            ? column.start - (area.width - column.width) / 2
            : min(max(current, column.start + column.width - area.width), column.start)
    }

    /// The strip laid out at the current scroll offset, windows anywhere along it, on screen or not. The focused
    /// column comes first in the stacking, then the others by distance from it.
    func stripLayout() -> Layout {
        var result = Layout()
        let area = stripArea, spans = columnSpans(in: area), offset = offset(for: spans, in: area)
        let gap = gaps.horizontal, last = columns.count - 1
        let front = focused.flatMap { columns.firstIndex(of: $0) } ?? 0
        for i in columns.indices.sorted(by: { (abs($0 - front), $0) < (abs($1 - front), $1) }) {
            let span = spans[i]
            let lead = i > 0 ? gap / 2 : 0, trail = i < last ? gap / 2 : 0
            let x = area.minX + span.start - offset
            let (a, b) = ((x + lead).rounded(), (x + span.width - trail).rounded())
            result.frames[columns[i]] = CGRect(x: a, y: area.minY, width: b - a, height: area.height)
            result.order.append(columns[i])
        }
        return result
    }

    /// Where a window of the strip goes on screen: where the strip puts it while at least `peek` of it is on
    /// screen, so a neighbour of the columns in view stays a gap from them, else hanging off the edge with `peek`
    /// left on, under that neighbour. At a wall it stays wholly on screen instead, behind the columns.
    func parked(_ frame: CGRect) -> CGRect {
        var x = frame.minX
        x = min(x, walls.contains(.right) ? bounds.maxX - frame.width : bounds.maxX - Self.peek)
        x = max(x, walls.contains(.left) ? bounds.minX : bounds.minX + Self.peek - frame.width)
        return CGRect(x: x, y: frame.minY, width: frame.width, height: frame.height)
    }

    /// Whether the strip shows the whole window now.
    public func isInView(_ id: WindowID) -> Bool {
        guard let frame = tiledLayout().frames[id] else { return true }
        return frame.minX >= bounds.minX - 1 && frame.maxX <= bounds.maxX + 1
    }

    /// Grow (positive) or shrink the focused window's column by `delta` points. False when nothing visibly changed.
    mutating func resizeColumn(by delta: CGFloat) -> Bool {
        guard let focused, let column = columns.firstIndex(of: focused) else { return false }
        let old = width(ofColumn: column)
        let (before, offset) = (tiledLayout(), scrollOffset)
        setWidth(ofColumn: column, old + Double(delta / stripArea.width))
        reveal(focused)
        // A step the minimum sizes swallow whole is undone, so the width does not drift out of sight.
        guard tiledLayout() == before else { return true }
        setWidth(ofColumn: column, old)
        scrollOffset = offset
        return false
    }

    /// `switch-preset-column-width`: give the focused window's column the first preset wider than it is now, or
    /// the first preset when it is as wide as the widest already, as niri does. Ends fullscreen. False when nothing
    /// changed.
    @discardableResult
    public mutating func switchPresetColumnWidth() -> Bool {
        guard let focused, let column = columns.firstIndex(of: focused), let first = presetColumnWidths.first else {
            return false
        }
        let current = width(ofColumn: column)
        let next = presetColumnWidths.first { $0 > current + 0.001 } ?? first
        // Ending fullscreen counts as a change: the column's width shows again.
        let wasFullscreen = isFullscreen
        isFullscreen = false
        guard abs(next - current) > 1e-9 else { return wasFullscreen }
        maximizedFrom[focused] = nil
        setWidth(ofColumn: column, next)
        reveal(focused)
        return true
    }

    /// `maximize-column`: widen the focused window's column to the whole screen, or give a column already that
    /// wide back the width it had before. The column stays in the strip. From fullscreen, it ends fullscreen and
    /// maximizes. False when there is no column.
    @discardableResult
    public mutating func toggleMaximizedColumn() -> Bool {
        guard let focused, let column = columns.firstIndex(of: focused) else { return false }
        let current = width(ofColumn: column)
        // From fullscreen, which hides the column's width, maximizing is what the window is asked for.
        if isFullscreen {
            isFullscreen = false
            if current >= 1 - 1e-9 { reveal(focused); return true }
        }
        if current >= 1 - 1e-9 {
            let restored = maximizedFrom.removeValue(forKey: focused) ?? columnWidth
            setWidth(ofColumn: column, restored < 1 - 1e-9 ? restored : columnWidth)
        } else {
            maximizedFrom[focused] = current
            setWidth(ofColumn: column, 1)
        }
        reveal(focused)
        return true
    }
}
