import ScuttleLayout

// The one command vocabulary shared by key bindings, the CLI and the menu bar.
// Names and arguments follow AeroSpace (MIT, github.com/nikitabobko/AeroSpace) where scuttle has the feature.

public enum Command: Equatable, Sendable {
    case workspace(WorkspaceTarget)
    case workspaceBackAndForth
    /// An explicit target for commands that already accept a window override in the dispatcher.
    indirect case targetWindow(UInt32, Command)
    case moveWindowToWorkspace(WorkspaceTarget, follow: Bool)
    case moveWindowToDisplay(DisplayTarget, follow: Bool)
    /// Focus the neighbour in a direction. `boundaries` says where the search stops, `action` what happens there.
    case focus(Direction, boundaries: FocusBoundaries = .workspace, action: BoundariesAction = .stop)
    case focusMonitor(MonitorTarget)
    /// `focus-monitor N`: the display numbered N by `list-monitors`, from 1.
    case focusMonitorNumber(Int)
    /// Swap the focused column with its neighbour, left or right.
    case move(Direction)
    /// Widen or narrow the focused column by N points.
    case resize(by: Int)
    /// Float or tile the window, or both to toggle: the one after the one that describes it now wins.
    case layout([LayoutName])
    case fullscreen
    /// Step the focused column through the preset widths, as niri's `switch-preset-column-width`.
    case switchPresetColumnWidth
    /// Widen the focused column to the whole screen, or give it back its width, as niri's `maximize-column`.
    case maximizeColumn
    case balanceSizes
    case clearMinimumSizes
    case reloadConfig
    case enable(Toggle)
    case listWindows(WindowQuery)
    case listWorkspaces(WorkspaceQuery)
    case listMonitors(MonitorQuery)
    /// The coordinator's state as JSON: displays, workspaces with their expected frames, placements and windows.
    case debugState
    /// Shell text run with `/bin/sh -c`, not waited for.
    case execAndForget(String)
}

/// A 1-based workspace number on the focused display, or its neighbour.
public enum WorkspaceTarget: Equatable, Sendable {
    case number(Int)
    case prev, next
}

public enum DisplayTarget: String, Equatable, Sendable {
    case prev, next
}

/// Where `focus` looks: the focused workspace, or on across displays up to their outer frame.
public enum FocusBoundaries: String, Equatable, Sendable {
    case workspace
    case allMonitorsOuterFrame = "all-monitors-outer-frame"
}

/// What `focus` does at its boundary: nothing and succeed, fail, or wrap to the far side of the
/// workspace or of all the displays.
public enum BoundariesAction: String, Equatable, Sendable {
    case stop, fail
    case wrapAroundTheWorkspace = "wrap-around-the-workspace"
    case wrapAroundAllMonitors = "wrap-around-all-monitors"
}

/// A display relative to the focused one: in a direction by frame, or next and previous in display order.
public enum MonitorTarget: String, Equatable, Sendable {
    case left, right, up, down, next, prev

    /// The direction for left, right, up and down; nil for next and prev.
    public var direction: Direction? { Direction(rawValue) }
}

/// The one of `names` to apply to a state `current` describes: the one after the last that describes it,
/// wrapping, so a list cycles and two toggle; the first when none does.
public func nextLayout<Name: Equatable>(in names: [Name], current: [Name]) -> Name {
    guard let last = names.lastIndex(where: current.contains) else { return names[0] }
    return names[(last + 1) % names.count]
}

/// A state for `layout`: floating or tiling for the window.
public enum LayoutName: String, Equatable, Sendable {
    case floating, tiling
}

public enum Toggle: String, Equatable, Sendable {
    case on, off, toggle
}

extension Direction {
    init?(_ word: String) {
        switch word {
        case "left": self = .left
        case "right": self = .right
        case "up": self = .up
        case "down": self = .down
        default: return nil
        }
    }
}
