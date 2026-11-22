import CoreGraphics

/// One Space's tiling state: the strip of columns, focus, fullscreen and the geometry settings used to lay it out.
public struct Workspace: Equatable, Sendable {
    /// The Space's visible rect, top-left origin.
    public var bounds: CGRect
    public var gaps: Gaps
    /// The strip: a horizontal container whose children are the columns, one window each, possibly none.
    public internal(set) var root: Container
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
    /// Sizes windows refused to go below. Columns grow to fit them.
    public var minimumSizes: [WindowID: CGSize] = [:]
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
        root = Container(.horizontal)
    }

    /// All windows, left to right.
    public var windows: [WindowID] { Node.container(root).windows }

    /// Whether the window is tiled here.
    public func contains(_ id: WindowID) -> Bool { root.path(of: id) != nil }

    /// Insert a window as a new column right of the focused one, and focus it.
    public mutating func insert(_ id: WindowID) {
        guard !contains(id) else { return }
        insertColumn(id)
        focus(id)
    }

    /// Remove a window and its column. If it was focused, focus moves to the most recently focused column left.
    public mutating func remove(_ id: WindowID) {
        guard let path = root.path(of: id) else { return }
        root.remove(at: path[0])
        columnWidths[id] = nil
        maximizedFrom[id] = nil
        if focused == id {
            isFullscreen = false
            focused = nil
            if let next = root.mostRecentWindow ?? windows.first { focus(next) }
        }
    }

    /// Put `new` in `old`'s place, keeping its size, focus and fullscreen: another tab of the same native tab group
    /// became the one shown. Does nothing if `old` is not here or `new` already is.
    public mutating func replace(_ old: WindowID, with new: WindowID) {
        guard let path = root.path(of: old), !contains(new) else { return }
        root.modify(at: Array(path.dropLast())) { $0.replace(at: path.last!, with: .window(new)) }
        if focused == old { focused = new }
        minimumSizes[old] = nil
        columnWidths[new] = columnWidths.removeValue(forKey: old)
        maximizedFrom[new] = maximizedFrom.removeValue(forKey: old)
    }

    /// Focus a window and scroll its column into view. Ends fullscreen unless it is the fullscreen window.
    public mutating func focus(_ id: WindowID) {
        guard let path = root.path(of: id) else { return }
        if focused != id { isFullscreen = false }
        focused = id
        for depth in path.indices {
            root.modify(at: Array(path.prefix(depth))) { $0.active = path[depth] }
        }
        reveal(id)
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
        guard !root.children.isEmpty else { return nil }
        let index = side.orientation == .vertical ? root.activeIndex : side.isForward ? root.children.count - 1 : 0
        return root.children[index].windows.first
    }

    /// Give every column the default width.
    public mutating func balanceSizes() {
        isFullscreen = false
        for id in columnWidths.keys { columnWidths[id] = columnWidth }
        maximizedFrom = [:]
        if let focused { reveal(focused) }
    }

    /// Toggle fullscreen for the focused window. The tree is not changed.
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
