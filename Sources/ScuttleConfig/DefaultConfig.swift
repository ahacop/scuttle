// The config scuttle writes on first run. Apart from the rules and bindings, which it spells out, its
// values are the built-in defaults, so a key left out of a user's file means what this file says.

extension Config {
    public static let defaultTOML = """
    #:schema https://ahacop.github.io/scuttle/schemas/scuttle.json
    # ~/.config/scuttle/scuttle.toml. Saved changes take effect at once.
    # A key left out of this file has the value shown here.
    # Every key and command: https://ahacop.github.io/scuttle/configuration/

    start-at-login = true
    workspaces = 5                  # across all displays, one native Space each
    follow-space-order = false      # true: workspaces are renumbered when Spaces are reordered in Mission Control
    default-tiling = true           # false: workspaces aren't tiled unless [workspace.N] says so
    follow-app-activation = true    # fast Space switching when you use Cmd-Tab or the Dock
    float-windows-without-fullscreen = true   # progress windows, About, Calculator and the like are floating
    block-native-fullscreen = false # true: a window put in macOS full screen is put back on its workspace and shown with fullscreen
    fullscreen-width = 1.0          # share of the display width for a fullscreen or lone window, centered
    # lone-window-width = 0.75      # lone windows only; if omitted, fullscreen-width is used

    # Example: follow every app but one. Replaces the follow-app-activation line above.
    # [follow-app-activation]
    # enabled = true
    # exclude-apps = ['com.synology.SynologyDrive']   # its menu bar popover is counted as a window

    # Example: only tile workspace 2.
    # default-tiling = false
    # [workspace.2]
    # tiling = true
    # [workspace.2.display.built-in]   # its settings while on the laptop screen
    # fullscreen-width = 0.8

    [scrolling]
    column-width = 0.5              # a new column's share of the display
    preset-column-widths = [0.33333, 0.5, 0.66667]   # the widths for switch-preset-column-width


    [gaps]
    inner = 8                       # between columns
    outer = 8                       # or { top = 8, bottom = 8, left = 8, right = 8 }

    # Display patterns: main, secondary, or part of a name as listed by `scuttle list-displays`.
    # A workspace is placed on the first display that matches its patterns, else on the main display.
    # [workspace-to-display]
    # 5 = 'secondary'

    # Overrides for one display.
    # [display.main]
    # gaps.outer.top = 44
    # [display.'DELL U3421WE']
    # fullscreen-width = 0.55       # on an ultrawide, a fullscreen or lone window is about half the width
    # lone-window-width = 0.75      # lone windows only; if omitted, fullscreen-width is used

    [borders]
    enabled = true
    width = 4
    active-color = '#e1e3e4'        # '#rrggbb' or '#rrggbbaa'
    inactive-color = '#494d64'
    order = 'below'                 # below | above (a click-through ring over the window)
    exclude-apps = []               # bundle IDs of apps whose windows have no border

    # Optional per-window border rules, separate from [[rules]]. If several match, the last one
    # applies. [borders] enabled = false and exclude-apps take priority over them.
    # [[borders.rules]]
    # app-id = 'com.example.editor'
    # window-identifier = '^DocumentSettingsWindow$' # AXIdentifier, not a numeric window ID
    # enabled = false

    [focus-follows-mouse]
    enabled = false
    delay-ms = 100                  # how long the pointer has to stay on a window before it is focused

    [swipe]
    enabled = false                 # true: the Spaces swipe moves focus between columns first
    space-switch = 'instant'        # instant (Space switch only past the last column) | native (macOS also gets the swipe); native on macOS 27+
    vertical = false                # up and down too; these are always passed to macOS

    [animations]
    enabled = true                  # window moves are animated; off while Reduce Motion is on
    duration-ms = 200               # about how long a move lasts
    resize = 'instant'              # instant: only positions are animated | glide: sizes are animated too

    [drag]
    placeholders = true             # outlines on a dragged window's column and the column it will be swapped with

    # mod: the modifier that mod- stands for in bindings. alt, ctrl, cmd, shift, hyper, meh, or several
    # joined by -, such as 'ctrl-alt'. alt, ctrl, cmd and shift: which key of each pair counts in bindings,
    # both | left | right. With alt = 'left', right Option can still be used to type special characters.
    [modifiers]
    mod = 'alt'
    alt = 'both'
    ctrl = 'both'
    cmd = 'both'
    shift = 'both'

    # scuttle commands to run on events. For exec-and-forget, $SCUTTLE_WORKSPACE, $SCUTTLE_PREV_WORKSPACE and
    # $SCUTTLE_DISPLAY are set in the workspace hooks, and $SCUTTLE_DISPLAYS and $SCUTTLE_PREV_DISPLAYS
    # (how many displays) in display-changed.
    # [hooks]
    # startup = ['exec-and-forget brew services restart sketchybar']
    # workspace-changed = ['exec-and-forget sketchybar --trigger workspace_change']
    # focus-changed = []
    # display-changed = []

    # The commands of every rule that matches a new window are run, in order.
    [[rules]]
    app-id = 'com.apple.systempreferences'   # also: app-name, title (regexes), kind (normal|dialog|sheet|panel)
    run = 'layout floating'

    [bindings]
    mod-1 = 'workspace 1'
    mod-2 = 'workspace 2'
    mod-3 = 'workspace 3'
    mod-4 = 'workspace 4'
    mod-5 = 'workspace 5'
    mod-shift-1 = 'move-window-to-workspace 1'
    mod-shift-2 = 'move-window-to-workspace 2'
    mod-shift-3 = 'move-window-to-workspace 3'
    mod-shift-4 = 'move-window-to-workspace 4'
    mod-shift-5 = 'move-window-to-workspace 5'
    mod-tab = 'workspace-back-and-forth'
    mod-h = 'focus left'
    mod-l = 'focus right'
    mod-shift-h = 'move left'
    mod-shift-l = 'move right'
    # Workspaces are stacked top to bottom, as in niri: the up and down keys are used to move between them.
    mod-j = 'workspace next'
    mod-k = 'workspace prev'
    mod-shift-j = 'move-window-to-workspace next --follow'
    mod-shift-k = 'move-window-to-workspace prev --follow'
    mod-minus = 'resize width -50'
    mod-equal = 'resize width +50'
    mod-r = 'switch-preset-column-width'
    mod-f = 'maximize-column'
    mod-shift-f = 'fullscreen'
    mod-v = 'layout floating tiling'
    """
}
