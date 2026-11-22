import CoreGraphics

/// Directional commands and resize. Each returns false when there was nothing to do.
extension Workspace {
    /// The window in `direction` from `id`: the column beside it. Up and down find none on one workspace.
    public func neighbor(of id: WindowID, _ direction: Direction) -> WindowID? {
        var layout = Layout()
        root.layout(in: bounds, gaps: .zero, padding: 0, virtual: true, into: &layout)
        guard let from = layout.frames[id] else { return nil }
        let candidates = layout.order.compactMap { other -> (id: WindowID, distance: CGFloat)? in
            guard other != id, let to = layout.frames[other] else { return nil }
            let distance = switch direction {
            case .left: from.midX - to.midX
            case .right: to.midX - from.midX
            case .up: from.midY - to.midY
            case .down: to.midY - from.midY
            }
            let overlaps = direction.orientation == .horizontal
                ? min(from.maxY, to.maxY) > max(from.minY, to.minY)
                : min(from.maxX, to.maxX) > max(from.minX, to.minX)
            return distance > 0 && overlaps ? (other, distance) : nil
        }
        return candidates.min { $0.distance < $1.distance }?.id
    }

    /// The window a trackpad swipe toward `direction` focuses: the column beside the focused one. Nil at the edge,
    /// where the swipe is macOS's again.
    public func swipeTarget(_ direction: Direction) -> WindowID? {
        focused.flatMap { neighbor(of: $0, direction) }
    }

    /// Swap two windows' columns, each keeping its column's width. Focus stays where it was.
    @discardableResult
    public mutating func swap(_ first: WindowID, _ second: WindowID) -> Bool {
        guard first != second, let a = root.path(of: first), let b = root.path(of: second) else { return false }
        root.modify(at: Array(a.dropLast())) { $0.replace(at: a.last!, with: .window(second)) }
        root.modify(at: Array(b.dropLast())) { $0.replace(at: b.last!, with: .window(first)) }
        if let focused { focus(focused) }
        return true
    }

    /// Move the focused window's column one step left or right, swapping it with its neighbour. Up and down do
    /// nothing: a column is one window.
    @discardableResult
    public mutating func move(_ direction: Direction) -> Bool {
        isFullscreen = false
        guard direction.orientation == .horizontal, let focused, let column = root.path(of: focused)?.first else { return false }
        let other = column + (direction.isForward ? 1 : -1)
        guard root.children.indices.contains(other) else { return false }
        let node = root.children[other]
        root.replace(at: other, with: root.children[column])
        root.replace(at: column, with: node)
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
