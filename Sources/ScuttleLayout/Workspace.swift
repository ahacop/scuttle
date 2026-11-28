import CoreGraphics

/// One Space's tiling state: the strip of columns, focus, fullscreen and the geometry settings used to lay it out.
public struct Workspace: Equatable, Sendable {
    /// The Space's visible rect, top-left origin.
    public var bounds: CGRect
    public var gaps: Gaps
    /// The strip: its columns left to right, one window each, possibly none.
    public internal(set) var columns: [WindowID] = []
    /// The focused window, if any.
    public internal(set) var focused: WindowID?
    /// Whether the focused window is shown fullscreen over the strip. Focusing another window or any layout
    /// command ends it.
    var isFullscreen = false
    /// The window shown fullscreen over the strip, if any.
    public var fullscreen: WindowID? { isFullscreen ? focused : nil }
    /// The share of the width inside the outer gaps a fullscreen window takes, centred. 1 fills the width.
    public var fullscreenWidth = 1.0
    /// A lone window's share, or nil to keep using the fullscreen width.
    public var loneWindowWidth: Double?
    /// The smallest each window goes: what its app says, or a size it refused to go below. Columns grow to fit them.
    public var minimumSizes: [WindowID: CGSize] = [:]
    /// The largest each window goes, where its app says. Columns shrink to them.
    public var maximumSizes: [WindowID: CGSize] = [:]
    /// The width of a new column, as a share of the width inside the outer gaps.
    public var columnWidth = 0.5
    /// The widths `switch-preset-column-width` steps through, as shares, narrowest first. niri's by default.
    public var presetColumnWidths: [Double] = Workspace.defaultPresetColumnWidths
    public static let defaultPresetColumnWidths = [0.33333, 0.5, 0.66667]
    /// The width a column had before `maximize-column` widened it, by its window.
    var maximizedFrom: [WindowID: Double] = [:]
    /// Each window's column width, as a share.
    var columnWidths: [WindowID: Double] = [:]
    /// How far the strip is scrolled, in points from its start. The layout clamps it.
    var scrollOffset: CGFloat = 0
    /// The edges of `bounds` with another display beyond them, where a window cannot hang over.
    public var walls: Set<Direction> = []

    /// An empty workspace.
    public init(bounds: CGRect, gaps: Gaps = .zero) {
        self.bounds = bounds
        self.gaps = gaps
    }

    /// All windows, left to right.
    public var windows: [WindowID] { columns }

    /// Whether the window is tiled here.
    public func contains(_ id: WindowID) -> Bool { columns.contains(id) }

    /// Insert a window as a new column right of the focused one, and focus it.
    public mutating func insert(_ id: WindowID) {
        guard !contains(id) else { return }
        insertColumn(id)
        focus(id)
    }

    /// Remove a window and its column. If it was focused, focus moves to the column that takes its place: the one
    /// that was on its right, or at the end of the strip the one on its left.
    public mutating func remove(_ id: WindowID) {
        guard let index = columns.firstIndex(of: id) else { return }
        columns.remove(at: index)
        columnWidths[id] = nil
        maximizedFrom[id] = nil
        if focused == id {
            isFullscreen = false
            focused = nil
            if !columns.isEmpty { focus(columns[min(index, columns.count - 1)]) }
        }
    }

    /// Put `new` in `old`'s place, keeping its size, focus and fullscreen: another tab of the same native tab group
    /// became the one shown. Does nothing if `old` is not here or `new` already is.
    public mutating func replace(_ old: WindowID, with new: WindowID) {
        guard let index = columns.firstIndex(of: old), !contains(new) else { return }
        columns[index] = new
        if focused == old { focused = new }
        minimumSizes[old] = nil
        maximumSizes[old] = nil
        columnWidths[new] = columnWidths.removeValue(forKey: old)
        maximizedFrom[new] = maximizedFrom.removeValue(forKey: old)
    }

    /// Focus a window and scroll its column into view. Ends fullscreen unless it is the fullscreen window.
    public mutating func focus(_ id: WindowID) {
        guard contains(id) else { return }
        if focused != id { isFullscreen = false }
        focused = id
        reveal(id)
    }

    /// Scrolls as little as shows the focused column whole again, after its width or a neighbour's changed for
    /// another reason than a command: a window's size limits becoming known.
    public mutating func revealFocused() {
        if let focused { reveal(focused) }
    }

    /// Focus the neighbour in `direction`. At the edge, `wrapping` focuses the window at the opposite edge
    /// instead. Returns false when there is nothing to focus.
    @discardableResult
    public mutating func focus(_ direction: Direction, wrapping: Bool = false) -> Bool {
        guard let focused,
              let target = neighbor(of: focused, direction) ?? (wrapping ? edgeWindow(direction.opposite) : nil),
              target != focused else { return false }
        focus(target)
        return true
    }

    /// The window at the `side` edge: the first or last column, or for up and down the focused one.
    public func edgeWindow(_ side: Direction) -> WindowID? {
        side.orientation == .vertical ? focused ?? columns.first : side.isForward ? columns.last : columns.first
    }

    /// Give every column the default width.
    public mutating func balanceSizes() {
        isFullscreen = false
        for id in columnWidths.keys { columnWidths[id] = columnWidth }
        maximizedFrom = [:]
        if let focused { reveal(focused) }
    }

    /// Toggle fullscreen for the focused window. The strip is not changed.
    public mutating func toggleFullscreen() {
        if focused != nil { isFullscreen.toggle() }
    }

    /// Frames and stacking for every window. A fullscreen window covers the bounds minus outer gaps, narrowed to
    /// `fullscreenWidth` and centred, and comes first; a lone window uses `loneWindowWidth` when set.
    /// Scrolled-out windows are parked where macOS lets them be, see `parked(_:)`.
    public func layout() -> Layout {
        var result = tiledLayout()
        result.frames = result.frames.mapValues(parked)
        let whole = gaps.inset(bounds)
        if let fullscreen {
            result.frames[fullscreen] = narrowed(whole, to: fullscreenWidth)
            result.order = [fullscreen] + result.order.filter { $0 != fullscreen }
        } else if result.frames.count == 1, let (id, frame) = result.frames.first, frame.isClose(to: whole, within: 1) {
            // Alone and filling the workspace.
            result.frames[id] = narrowed(frame, to: loneWindowWidth ?? fullscreenWidth)
        }
        return result
    }

    /// Keep the window centred within its original frame when narrowing it.
    private func narrowed(_ frame: CGRect, to share: Double) -> CGRect {
        guard share < 1 else { return frame }
        let width = (frame.width * share).rounded()
        return CGRect(x: frame.minX + ((frame.width - width) / 2).rounded(), y: frame.minY, width: width, height: frame.height)
    }

    /// The layout ignoring fullscreen, used for geometry questions.
    func tiledLayout() -> Layout {
        stripLayout()
    }

}
