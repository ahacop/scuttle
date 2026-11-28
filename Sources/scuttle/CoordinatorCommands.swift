import ScuttleCommands
import ScuttleConfig
import ScuttleLayout

// What commands ask of the coordinator: workspace commands on the focused window's Space, floating, and
// taking in a window scuttle moved to another Space.
extension Coordinator {
    /// Settling windows are still floating on screen, unless a command has already requested tiling.
    func isFloating(_ id: WindowID) -> Bool? {
        placements[id]?.floating ?? settlements[id].map { $0.floating ?? true }
    }

    /// The workspace of the display's current Space, if scuttle has one.
    func workspace(on display: Display) -> Workspace? {
        workspaces[display.currentSpaceID]
    }

    /// A queued swipe must still refer to the same focused tile in the same Space, not follow a moved window.
    func swipeTarget(on space: UInt64, from id: WindowID, direction: Direction) -> WindowID? {
        guard enabled, placements[id]?.space == space, let workspace = workspaces[space],
              workspace.focused == id, let target = workspace.swipeTarget(direction),
              placements[target]?.space == space else { return nil }
        return target
    }

    /// Whether the window shows whole: false only for a column scrolled partly or wholly out of view.
    func isInView(_ id: WindowID) -> Bool {
        placements[id]?.space.flatMap { workspaces[$0]?.isInView(id) } ?? true
    }

    /// How a window is laid out, for `%{window-layout}`: `tiling` in a column, `fullscreen` for scuttle's fullscreen,
    /// `floating` for any window that is not tiled.
    func layoutName(of id: WindowID) -> String {
        guard let key = placements[id]?.space, let workspace = workspaces[key], workspace.contains(id) else { return "floating" }
        return workspace.fullscreen == id ? "fullscreen" : "tiling"
    }

    /// The layout of the workspace on a Space, for `%{workspace-layout}`: always `scrolling`. Nil for a Space
    /// scuttle has no strip for, such as a native full-screen one.
    func layoutName(ofWorkspace space: UInt64) -> String? {
        workspaces[space] == nil ? nil : "scrolling"
    }

    /// Runs a command on the workspace of a window (the focused one by default), focused in that workspace, and applies
    /// what changed. Nil if the window is not tiled.
    func command<T>(on id: WindowID? = nil, _ change: (inout Workspace) -> T) -> T? {
        let id = id ?? focusedWindow
        guard let key = placements[id]?.space else { return nil }
        edit(key) { $0.focus(id) }
        let result = edit(key, change)
        flush()
        return result
    }

    /// Floats a tiled window where it stands, or tiles a floating one in a new column at the end of its Space's strip.
    /// A window held as a possible tab is released, so it cannot take over a tile once floated.
    /// During initial classification, remember the choice until AX settles. False for an unmanaged window.
    @discardableResult
    func setFloating(_ id: WindowID, _ floating: Bool) -> Bool {
        if let settlement = settlements[id] {
            settlement.floating = floating
            return true
        }
        guard let placement = placements[id], let window = model.windows[id] else { return false }
        if let space = placement.space { edit(space) { $0.remove(id) } }
        heldTabs[id] = nil
        placements[id] = Placement(floating: floating, space: nil)
        track(window)
        flush()
        return true
    }

    /// Moves a window scuttle just moved to another Space into that Space's workspace now, rather than on the next event.
    /// `source` requests a focus handoff there. The caller captures it before moving, only for a focused window
    /// it isn't following; remembered workspace focus and tiled placement cannot tell us that for a floating window.
    func windowMoved(_ id: WindowID, refocusFrom source: UInt64? = nil) {
        guard model.windows[id] != nil else { return }
        // Re-reads its Space; the update it publishes reaches handle, which tracks the window and flushes.
        model.refresh(id)
        guard let source, let successor = workspaces[source]?.focused, successor != id else { return }
        focus(successor)
    }
}
