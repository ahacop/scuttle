import AppKit
import DankyLayout

// Dragging a tiled window with the mouse. On release, a drag that moved one edge of the window on an axis is a
// resize: the tree takes the new size and the other tiles make room. Any other drag is a move: dropping it with the
// pointer over another tile swaps the two, anywhere else puts it back. While a move is under way, placeholders outline the window's tile and where it
// would land. Only frames that change while the mouse button is down count as a drag, which keeps danky's own frame
// writes and apps moving themselves out of it.

extension Coordinator {
    func noteFrameChange(of id: WindowID) {
        guard !MissionControl.shared.active else { return }
        if dragging == id { return followDrag() }
        // Only tiled windows have a Space. Disabled, danky leaves drags alone.
        guard enabled, dragging == nil, let key = placements[id]?.space, !isAnimating(id), mouseButtonDown,
              let tile = workspaces[key]?.layout().frames[id] else { return }
        drag = (id, tile)
        followDrag()
        watchDragEnd()
    }

    private func watchDragEnd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let (id, start) = self.drag else { return }
            if self.mouseButtonDown {
                self.followDrag()
                self.watchDragEnd()
            } else {
                self.drag = nil
                self.placeholders.hide()
                self.dropped(id, from: start)
            }
        }
    }

    /// Lets go of the drag under way without acting on its release, as when danky is disabled mid-drag.
    func cancelDrag() {
        guard drag != nil else { return }
        drag = nil
        placeholders.hide()
    }

    /// Resizes or swaps by how the window moved from `start`, its tile when the drag began. Either way, or when it
    /// went back where it started, it then goes to its tile, which may have changed during the drag.
    private func dropped(_ id: WindowID, from start: CGRect) {
        guard let key = placements[id]?.space, let workspace = workspaces[key], let window = model.windows[id] else { return }
        let layout = workspace.layout()
        guard let expected = layout.frames[id] else { return }
        if window.frame.isClose(to: start, within: 2) {
            guard !window.frame.isClose(to: expected, within: 2) else { return }
        } else if let edges = movedEdges(from: start, to: window.frame) {
            edit(key) { $0.resize(id, to: window.frame.size, moving: edges) }
        } else if let target = dropTarget(of: id, in: layout) {
            edit(key) { $0.swap(id, target) }
        }
        layouts.dirty.insert(key)
        flush()
    }

    /// Notes where the pointer rests and outlines the dragged window's tile and where a drop would put it, while
    /// the drag is a move.
    private func followDrag() {
        guard let (id, start) = drag, let key = placements[id]?.space, let workspace = workspaces[key],
              let window = model.windows[id] else { return placeholders.hide() }
        let layout = workspace.layout()
        guard let home = layout.frames[id], !window.frame.isClose(to: start, within: 2),
              movedEdges(from: start, to: window.frame) == nil else {
            return placeholders.hide()
        }
        guard config.drag.placeholders else { return placeholders.hide() }
        let landing = dropTarget(of: id, in: layout).flatMap { layout.frames[$0] }
        placeholders.show(dragged: id, home: home, target: landing, cornerRadius: CGFloat(window.cornerRadius))
    }

    /// The tile under the pointer, the frontmost where tiles overlap.
    private func dropTarget(of id: WindowID, in layout: Layout) -> WindowID? {
        guard let pointer else { return nil }
        return layout.order.first { $0 != id && layout.frames[$0]!.contains(pointer) }
    }

    private var pointer: CGPoint? { CGEvent(source: nil)?.location }

    /// The edges a resize moved, going from the tile to the dropped frame: on each axis, one edge moved more than
    /// 2 pt and the other stayed. Nil for a move, where some axis had both edges move, or nothing did.
    private func movedEdges(from tile: CGRect, to frame: CGRect) -> Set<Direction>? {
        let axes = [((Direction.left, tile.minX, frame.minX), (Direction.right, tile.maxX, frame.maxX)),
                    ((Direction.up, tile.minY, frame.minY), (Direction.down, tile.maxY, frame.maxY))]
        var edges: Set<Direction> = []
        for (lead, trail) in axes {
            let moved = [lead, trail].filter { abs($0.2 - $0.1) > 2 }.map(\.0)
            if moved.count == 2 { return nil }
            edges.formUnion(moved)
        }
        return edges.isEmpty ? nil : edges
    }

    private var mouseButtonDown: Bool { CGEventSource.buttonState(.combinedSessionState, button: .left) }
}
