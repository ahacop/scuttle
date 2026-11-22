// The config danky writes on first run. Apart from the rules and bindings, which it spells out, its
// values are the built-in defaults, so a key left out of a user's file means what this file says.

extension Config {
    public static let defaultTOML = """
    #:schema https://ahacop.github.io/danky/schemas/danky.json
    # ~/.config/danky/danky.toml. Saved changes take effect at once.
    # A key you leave out keeps the value shown here.
    # Every key and command: https://ahacop.github.io/danky/configuration/

    start-at-login = true
    workspaces = 5                  # across all displays, one native Space each
    follow-space-order = false      # true renumbers workspaces when you reorder Spaces in Mission Control
    default-tiling = true           # false leaves workspaces untiled unless overridden
    follow-app-activation = true    # Cmd-Tab and Dock clicks switch Spaces the fast way
    float-windows-without-fullscreen = true   # progress windows, About, Calculator and the like float
    block-native-fullscreen = true  # macOS full screen becomes danky's fullscreen on the window's workspace
    fullscreen-width = 1.0          # share of the width a fullscreen window, or a window alone, takes, centred
    # lone-window-width = 0.75      # lone windows only; omitted uses the resolved fullscreen-width

    # Example: follow every app but one. Replaces the follow-app-activation line above.
    # [follow-app-activation]
    # enabled = true
    # exclude-apps = ['com.synology.SynologyDrive']   # its menu bar popover counts as a window

    # Example: only tile workspace 2.
    # default-tiling = false
    # [workspace.2]
    # tiling = true
    # [workspace.2.display.built-in]   # its settings while on the laptop screen
    # fullscreen-width = 0.8

    [scrolling]
    column-width = 0.5              # a new column's share of the display
    preset-column-widths = [0.33333, 0.5, 0.66667]   # what switch-preset-column-width steps through


    [gaps]
    inner = 8                       # or { horizontal = 8, vertical = 8 }
    outer = 8                       # or { top = 8, bottom = 8, left = 8, right = 8 }

    # Display patterns: main, secondary, or part of a name as `danky list-displays` prints it.
    # A workspace lives on the first display its patterns match, else on the main display.
    # [workspace-to-display]
    # 5 = 'secondary'

    # Overrides for one display.
    # [display.main]
    # gaps.outer.top = 44
    # [display.'DELL U3421WE']
    # fullscreen-width = 0.55       # on an ultrawide, a fullscreen or lone window takes half the width
    # lone-window-width = 0.75      # lone windows only; omitted uses the resolved fullscreen-width

    [borders]
    enabled = true
    width = 4
    active-color = '#e1e3e4'        # '#rrggbb' or '#rrggbbaa'
    inactive-color = '#494d64'
    order = 'below'                 # below | above (a click-through ring over the window)
    exclude-apps = []               # bundle IDs whose windows get no border

    # Optional per-window decoration; independent of [[rules]] placement commands.
    # Last match wins; [borders].enabled = false and exclude-apps always veto.
    # [[borders.rules]]
    # app-id = 'com.example.editor'
    # window-identifier = '^DocumentSettingsWindow$' # AXIdentifier, not a numeric window ID
    # enabled = false

    [focus-follows-mouse]
    enabled = false
    delay-ms = 100                  # how long the pointer rests on a window before it takes focus

    [swipe]
    enabled = false                 # the Spaces swipe focuses the next window of a tiled workspace first
    space-switch = 'instant'        # instant (focus, then switch past the edge) | native (macOS also acts); native on macOS 27+
    vertical = false                # up and down too; always native, so macOS may also open an overview

    [animations]
    enabled = true                  # windows glide to their tiles; off while Reduce Motion is on
    duration-ms = 200               # roughly how long a window takes to arrive
    resize = 'instant'              # instant: sizes jump, positions glide (smooth everywhere) | glide: sizes glide too

    [drag]
    placeholders = true             # outline where a dragged tile came from and the tile it will swap with

    # Which key of each pair bindings answer to: both | left | right. With alt = 'left',
    # right Option still types special characters.
    [modifiers]
    alt = 'both'
    ctrl = 'both'
    cmd = 'both'
    shift = 'both'

    # danky commands run on events. exec-and-forget gets $DANKY_WORKSPACE, $DANKY_PREV_WORKSPACE and $DANKY_DISPLAY
    # in the workspace hooks, and $DANKY_DISPLAYS, $DANKY_PREV_DISPLAYS (how many displays) in display-changed.
    # [hooks]
    # startup = ['exec-and-forget brew services restart sketchybar']
    # workspace-changed = ['exec-and-forget sketchybar --trigger workspace_change']
    # focus-changed = []
    # display-changed = []

    # Every rule whose conditions all match a new window runs, in order.
    [[rules]]
    app-id = 'com.apple.systempreferences'   # also: app-name, title (regexes), kind (normal|dialog|sheet|panel)
    run = 'layout floating'

    [bindings]
    ctrl-left = 'workspace prev'
    ctrl-right = 'workspace next'
    alt-1 = 'workspace 1'
    alt-2 = 'workspace 2'
    alt-3 = 'workspace 3'
    alt-4 = 'workspace 4'
    alt-5 = 'workspace 5'
    alt-6 = 'workspace 6'
    alt-7 = 'workspace 7'
    alt-8 = 'workspace 8'
    alt-9 = 'workspace 9'
    alt-shift-1 = 'move-window-to-workspace 1'
    alt-shift-2 = 'move-window-to-workspace 2'
    alt-shift-3 = 'move-window-to-workspace 3'
    alt-shift-4 = 'move-window-to-workspace 4'
    alt-shift-5 = 'move-window-to-workspace 5'
    alt-shift-6 = 'move-window-to-workspace 6'
    alt-shift-7 = 'move-window-to-workspace 7'
    alt-shift-8 = 'move-window-to-workspace 8'
    alt-shift-9 = 'move-window-to-workspace 9'
    alt-tab = 'workspace-back-and-forth'
    alt-h = 'focus left'
    alt-l = 'focus right'
    alt-shift-h = 'move left'
    alt-shift-l = 'move right'
    # Workspaces stack top to bottom, as in niri: up and down go between them.
    alt-j = 'workspace next'
    alt-k = 'workspace prev'
    alt-shift-j = 'move-window-to-workspace next --follow'
    alt-shift-k = 'move-window-to-workspace prev --follow'
    alt-minus = 'resize width -50'
    alt-equal = 'resize width +50'
    alt-r = 'switch-preset-column-width'
    alt-f = 'maximize-column'
    alt-shift-f = 'fullscreen'
    alt-v = 'layout floating tiling'
    alt-shift-n = 'move-window-to-display next'
    """
}
