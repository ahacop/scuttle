import CoreGraphics

/// One Space's tiling state: the strip of columns, focus, fullscreen and the geometry settings used to lay it out.
public struct Workspace: Equatable, Sendable {
    /// The Space's visible rect, top-left origin.
    public var bounds: CGRect
    public var gaps: Gaps
    public var accordionPadding: CGFloat
    /// The strip. The root is always a horizontal container of columns, possibly empty.
    public internal(set) var root: Container
    /// The focused window, if any.
    public internal(set) var focused: WindowID?
    /// Whether the focused window is shown fullscreen over the tree. Focusing another window or any layout
    /// command ends it.
    var isFullscreen = false
    /// The window shown fullscreen over the tree, if any.
    public var fullscreen: WindowID? { isFullscreen ? focused : nil }
    /// The share of the width inside the outer gaps a fullscreen window takes, centred. 1 fills the width.
    public var fullscreenWidth = 1.0
    /// A lone window's share, or nil to keep using the fullscreen width.
    public var loneWindowWidth: Double?
    /// Sizes windows refused to go below. Tiles grow to them when their siblings can give the space.
    public var minimumSizes: [WindowID: CGSize] = [:]
    /// The width of a new column, as a share of the width inside the outer gaps.
    public var columnWidth = 0.5
    /// The widths `switch-preset-column-width` steps through, as shares, narrowest first. niri's by default.
    public var presetColumnWidths: [Double] = Workspace.defaultPresetColumnWidths
    public static let defaultPresetColumnWidths = [0.33333, 0.5, 0.66667]
    /// The width a column had before `maximize-column` widened it, kept on each of its windows.
    var maximizedFrom: [WindowID: Double] = [:]
    /// Each window's column width, as a share. Every window of a column has its column's width.
    var columnWidths: [WindowID: Double] = [:]
    /// How far the strip is scrolled, in points from its start. The layout clamps it.
    var scrollOffset: CGFloat = 0
    /// The edges of `bounds` with another display beyond them, where a window cannot hang over.
    public var walls: Set<Direction> = []

    /// An empty workspace.
    public init(bounds: CGRect, gaps: Gaps = .zero, accordionPadding: CGFloat = 30) {
        self.bounds = bounds
        self.gaps = gaps
        self.accordionPadding = accordionPadding
        root = Container(.horizontal)
    }

    /// All windows in tree order.
    public var windows: [WindowID] { Node.container(root).windows }

    /// Whether the window is tiled here.
    public func contains(_ id: WindowID) -> Bool { root.path(of: id) != nil }

    /// Insert a window as a new column right of the focused one, and focus it.
    public mutating func insert(_ id: WindowID) {
        guard !contains(id) else { return }
        insertColumn(id)
        focus(id)
    }

    /// Remove a window. Its share goes to its siblings, redundant containers collapse.
    /// If it was focused, focus moves to the window that took its place.
    public mutating func remove(_ id: WindowID) {
        guard let path = root.path(of: id) else { return }
        root.modify(at: Array(path.dropLast())) { $0.remove(at: path.last!) }
        normalize()
        columnWidths[id] = nil
        maximizedFrom[id] = nil
        if focused == id {
            isFullscreen = false
            focused = nil
            if let next = root.mostRecentWindow ?? windows.first { focus(next) }
        }
    }

    /// Lay `ids` out afresh as one column each, in order, keeping the focus and the column widths.
    private mutating func rebuild(_ ids: [WindowID]) {
        root = Container(.horizontal, .tiles, ids.map(Node.window))
        for id in ids { columnWidths[id] = columnWidths[id] ?? columnWidth }
        if let focused { focus(focused) }
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

    /// Undo every tree edit: every window gets a column of its own, in order.
    public mutating func flatten() {
        isFullscreen = false
        rebuild(windows)
    }

    /// Focus a window and mark it most recent along its path, so accordions show it on top.
    /// Ends fullscreen unless it is the fullscreen window.
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

    /// The window snapped to the `side` edge: containers along that axis give their first or last child,
    /// the others their most recently focused one. Adapted from AeroSpace's findLeafWindowRecursive(snappedTo:).
    public func edgeWindow(_ side: Direction) -> WindowID? {
        let layout = tiledLayout()
        var container = root, path: [Int] = []
        while !container.children.isEmpty {
            let index = axisOfContainer(at: path, in: layout) != side.orientation ? container.activeIndex
                : side.isForward ? container.children.count - 1 : 0
            switch container.children[index] {
            case .window(let id): return id
            case .container(let c): (container, path) = (c, path + [index])
            }
        }
        return nil
    }

    /// Give every container in the tree equal ratios.
    public mutating func balanceSizes() {
        isFullscreen = false
        root.balance()
        for id in columnWidths.keys { columnWidths[id] = columnWidth }
        if let focused { reveal(focused) }
    }

    /// The window's parent container, nil if the window is not here.
    public func container(of id: WindowID) -> Container? {
        root.path(of: id).map { root.container(at: Array($0.dropLast())) }
    }

    /// The axis of the window's parent container, `auto` resolved, nil if the window is not here.
    public func containerAxis(of id: WindowID) -> Orientation? {
        root.path(of: id).map { axisOfContainer(at: Array($0.dropLast())) }
    }

    /// The container `layout` commands change for the window, with the axis it runs along now: its column. Nil if the window is not here.
    public func layoutContainer(of id: WindowID) -> (container: Container, axis: Orientation)? {
        guard let path = root.path(of: id) else { return nil }
        let containerPath = Array(path.dropLast())
        return (root.container(at: containerPath), axisOfContainer(at: containerPath))
    }

    /// The axis the container at `path` runs along now, `auto` resolved from the rectangle it is laid out in,
    /// so minimum sizes count as they do on screen.
    func axisOfContainer(at path: [Int]) -> Orientation {
        axisOfContainer(at: path, in: tiledLayout())
    }

    /// The axis of the container at `path` in `layout`, for callers asking about several containers at once.
    func axisOfContainer(at path: [Int], in layout: Layout) -> Orientation {
        root.container(at: path).axis(in: rect(at: path, in: layout))
    }

    /// The rectangle the container at `path` is laid out in, gaps and minimum sizes applied.
    func rect(at path: [Int], in layout: Layout) -> CGRect {
        layout.containerRects[path] ?? gaps.inset(bounds)
    }

    /// Set the layout mode of the focused window's column: its windows stacked top to bottom as tiles, or as an
    /// accordion. Ratios are kept, so tiles come back as they were. A window alone in its column has no container
    /// to change.
    public mutating func setMode(_ mode: LayoutMode) {
        isFullscreen = false
        guard let focused, let path = root.path(of: focused), path.count > 1 else { return }
        root.modify(at: Array(path.dropLast())) { $0.mode = mode }
        normalize()
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

    /// Tidy the tree after an edit. The strip stays the root even with one column left.
    mutating func normalize() {
        root.normalize()
    }
}
