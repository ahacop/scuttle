import CoreGraphics

/// Directional commands and resize. Each returns false when there was nothing to do.
extension Workspace {
    /// The window in `direction` from `id`: the column beside it. Up and down find none on one workspace.
    public func neighbor(of id: WindowID, _ direction: Direction) -> WindowID? {
        guard direction.orientation == .horizontal, let column = columns.firstIndex(of: id) else { return nil }
        let other = column + (direction.isForward ? 1 : -1)
        return columns.indices.contains(other) ? columns[other] : nil
    }

    /// The window a trackpad swipe toward `direction` focuses: the column beside the focused one. Nil at the edge,
    /// where the swipe is macOS's again.
    public func swipeTarget(_ direction: Direction) -> WindowID? {
        focused.flatMap { neighbor(of: $0, direction) }
    }

    /// Swap two windows' places in the strip, each keeping its own width. Focus stays where it was.
    @discardableResult
    public mutating func swap(_ first: WindowID, _ second: WindowID) -> Bool {
        guard first != second, let a = columns.firstIndex(of: first), let b = columns.firstIndex(of: second) else { return false }
        columns.swapAt(a, b)
        if let focused { focus(focused) }
        return true
    }

    /// Move the focused window's column one step left or right, swapping it with its neighbour. Up and down do
    /// nothing: a column is one window.
    @discardableResult
    public mutating func move(_ direction: Direction) -> Bool {
        isFullscreen = false
        guard direction.orientation == .horizontal, let focused, let column = columns.firstIndex(of: focused) else { return false }
        let other = column + (direction.isForward ? 1 : -1)
        guard columns.indices.contains(other) else { return false }
        columns.swapAt(column, other)
        focus(focused)
        return true
    }

    /// Widen (positive) or narrow the focused window's column by `delta` points. False when nothing visibly changed.
    @discardableResult
    public mutating func resize(by delta: CGFloat) -> Bool {
        isFullscreen = false
        return resizeColumn(by: delta)
    }
}
