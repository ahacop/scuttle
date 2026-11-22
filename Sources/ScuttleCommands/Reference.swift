// The command reference: one line of syntax and one of description per command, in the order a user
// would look for them. This list owns the set of command names and their syntax: parse errors quote it and
// `scuttle help` prints it. docs/commands.md owns the prose, and DocsTests holds its table to these names.

extension Command {
    public struct Doc: Equatable, Sendable {
        public let syntax: String
        public let description: String

        /// The command name, the first word of the syntax.
        public var name: String { String(syntax.prefix { $0 != " " }) }
    }

    public static let all: [Doc] = [
        Doc(syntax: "workspace <number|prev|next>",
            description: "Show a workspace (a native Space), numbered from 1 across displays, and focus its display. "
                + "prev and next step through the focused display's workspaces."),
        Doc(syntax: "workspace-back-and-forth",
            description: "Switch to the workspace that was focused before the current one."),
        Doc(syntax: "move-window-to-workspace <number|prev|next> [--follow] [--window-id <id>]",
            description: "Move the focused window, or a managed window from list-windows --all with --window-id. "
                + "With an explicit ID, prev/next step from that window's workspace; otherwise from the focused display's. "
                + "Without --follow, keep focus here, even when bringing a window here. With --follow, show and focus the destination window, even if already there."),
        Doc(syntax: "move-window-to-display <next|prev> [--follow] [--window-id <id>]",
            description: "Move the focused window, or the managed window selected by --window-id, to the next or previous display's current workspace. "
                + "Without --follow, keep focus here. With --follow, focus it there."),
        Doc(syntax: "focus <left|down|up|right> [--boundaries workspace|all-monitors-outer-frame] "
                + "[--boundaries-action stop|fail|wrap-around-the-workspace|wrap-around-all-monitors]",
            description: "Focus the column beside the focused one, left or right. At the workspace edge, and for up and down, "
                + "--boundaries all-monitors-outer-frame goes on to the display in that direction and focuses the window "
                + "at its near edge. At the last edge, --boundaries-action stops (the default), fails, wraps to the far "
                + "side of the workspace, or, with all-monitors-outer-frame, to the display at the far side. "
                + "--wrap-around is short for --boundaries-action wrap-around-the-workspace. Never switches workspace."),
        Doc(syntax: "focus-monitor <left|down|up|right|next|prev|N>",
            description: "Focus the display in a direction, the next or previous one, or display N as list-monitors numbers it: its most recently focused window, "
                + "or the display itself when its workspace is empty, so workspace commands act on it."),
        Doc(syntax: "move <left|right>",
            description: "Swap the focused column with its neighbour on that side."),
        Doc(syntax: "resize width <+N|-N>",
            description: "Widen or narrow the focused column by N points."),
        Doc(syntax: "switch-preset-column-width",
            description: "Give the focused column the next of [scrolling] preset-column-widths, wider than it is now, "
                + "wrapping to the narrowest, as niri does."),
        Doc(syntax: "maximize-column",
            description: "Widen the focused column to the whole screen, or give a maximized column back its width. "
                + "The column stays in the strip."),
        Doc(syntax: "layout <floating|tiling>... [--window-id <id>]",
            description: "Float the focused window, or tile it into a column of its own. "
                + "--window-id selects a managed window from list-windows --all instead, without focusing it. "
                + "With both, apply the one after the one that describes the window now, so 'layout floating tiling' toggles."),
        Doc(syntax: "fullscreen",
            description: "Toggle the focused window filling the workspace, over the strip. The strip is kept."),
        Doc(syntax: "balance-sizes",
            description: "Give every column on the workspace the default width."),
        Doc(syntax: "clear-minimum-sizes",
            description: "Forget the minimum window sizes scuttle has learned for every app, and re-apply every layout."),
        Doc(syntax: "reload-config",
            description: "Reload ~/.config/scuttle/scuttle.toml. On an error the previous config stays."),
        Doc(syntax: "enable <on|off|toggle>",
            description: "Turn scuttle on or off. Off stops tiling and restores every window to its original frame and Space."),
        Doc(syntax: "list-workspaces [--all|--focused|--monitor <focused|all|n>...] [--visible [no]] [--empty [no]] [--format <format>]",
            description: "Print workspace numbers, one per line, of the focused display by default. --all covers every display. "
                + "--focused prints the focused workspace. "
                + "Format variables: " + vars(WorkspaceQuery.variables) + "."),
        Doc(syntax: "list-windows [--all|--focused|--monitor <focused|all|n>...] [--workspace <focused|visible|n>...] "
                + "[--app-bundle-id <id>] [--format <format>]",
            description: "Print windows as 'id | app | title', of the focused display by default. --focused prints the focused window. "
                + "Format variables: " + vars(WindowQuery.variables) + "."),
        Doc(syntax: "list-monitors [--focused [no]] [--format <format>]",
            description: "Print displays as 'number | name'. Format variables: " + vars(MonitorQuery.variables) + "."),
        Doc(syntax: "list-displays [--focused [no]] [--format <format>]",
            description: "The same as list-monitors."),
        Doc(syntax: "debug-state",
            description: "Print the tiling state as JSON: displays, each workspace's tree and expected frames, "
                + "placements and windows. For tests and bug reports."),
        Doc(syntax: "exec-and-forget <shell command>",
            description: "Run the rest of the line with /bin/sh -c without waiting. Its output goes to scuttle's log."),
    ]
}

private func vars(_ names: [String]) -> String {
    (names + Format.special).map { "%{\($0)}" }.joined(separator: ", ")
}
