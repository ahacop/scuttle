---
layout: default
title: Configuration
description: The TOML config file, every key and its default, and the key syntax.
permalink: /configuration/
---

# Configuration

The config file is `~/.config/scuttle/scuttle.toml`. scuttle writes it on first
run and reloads it when you save. If the file is a symlink, scuttle follows it,
and replacing the link also reloads. If the link points to a missing file,
scuttle keeps the current config and shows the error in the menu.

- Every key is optional. A key you leave out keeps its default. Without
  `[bindings]` there are no key bindings, and without `[[rules]]` there are no
  rules.
- Unknown keys are errors. If the config has an error, scuttle keeps the
  previous config and shows the error in the menu.
- `scuttle doctor [--config <path>]` checks the config, including commands and
  key names.
- The [JSON Schema](schemas/scuttle.json) gives completion in editors that read
  Taplo's `#:schema` line, such as Zed, or VS Code with Even Better TOML.

## Top level

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `start-at-login` | `true` | Start scuttle when you log in. |
| `workspaces` | `5` | The number of workspaces, across all displays. Each workspace is one native Space. On macOS 27 and later, scuttle creates and removes Spaces to match. On macOS 26, you add desktops yourself; see [desktop setup](#desktop-setup-on-macos-26). |
| `follow-space-order` | `false` | If `true`, reordering Spaces in Mission Control renumbers the workspaces. On each display, the leftmost Space gets the lowest number, and windows stay where they are. If `false`, each workspace keeps its number, and scuttle moves its windows back to that number's Space the next time it arranges workspaces: on a config reload, a display change, or when a Space is removed. |
| `default-tiling` | `true` | If `false`, workspaces don't tile unless [`[workspace.<number>]`](#workspacenumber) turns tiling on. |
| `follow-app-activation` | `true` | Cmd-Tab and Dock clicks switch Spaces quickly. This needs the macOS setting "When switching to an application, switch to a Space with open windows" turned off. To leave some apps out, use the [`[follow-app-activation]`](#follow-app-activation) table instead. |
| `block-native-fullscreen` | `true` | When a window enters macOS full screen (the green button or Control-Command-F), scuttle puts it back in its column and shows it with scuttle's `fullscreen` instead, so it stays on its workspace. If `false`, macOS full screen works as usual and the window gets its own Space. |
| `float-windows-without-fullscreen` | `true` | Float windows that can't go full screen, such as Finder's copy progress, About This Mac and Calculator. Terminals and editors that hide their title bar still tile. A `layout tiling` rule tiles a window anyway. |
| `fullscreen-width` | `1.0` | How much of the display width, inside the outer gaps, a `fullscreen` window takes. The window is centered. From `0.1` to `1`. [`[display.<pattern>]`](#displaypattern) and [`[workspace.<number>]`](#workspacenumber) can override it. |
| `lone-window-width` | the `fullscreen-width` in effect | The width of a window that is alone on its workspace and whose column fills the display, for example at column width `1` or maximized. The window is centered. From `0.1` to `1`. A workspace's own table wins over the most specific matching display table, which wins over the top level. |

</div>

With `follow-space-order`, scuttle follows reordering within each display only.
`[workspace-to-display]` still decides which display a workspace is on: if you
drag a Space to another display, its windows go back to the configured display
the next time scuttle arranges workspaces. Workspace numbers follow position, so
`[workspace.2]`, and any command or rule that names workspace 2, applies to
whichever Space is second. Turning the option on and running `reload-config`
also adopts the current order.

## `[follow-app-activation]`

The table form of `follow-app-activation`. Use it in place of the top-level
key. Following only works while scuttle is running and enabled. Turning it off
does not change the macOS setting back; see [First run](index.md#first-run).

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `true` | The same as `follow-app-activation = true`. |
| `exclude-apps` | `[]` | Bundle IDs of apps to leave out, such as a menu bar app whose popover counts as a window. |

</div>

## `[workspace.<number>]`

Settings for one workspace. They override the top-level `default-tiling` and
widths. Workspaces are numbered from 1 across all displays. A table for a
number above `workspaces` does nothing, and `scuttle doctor` warns about it.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `tiling` | `default-tiling` | Whether the workspace tiles. |
| `fullscreen-width` | top-level `fullscreen-width` | The `fullscreen` width on this workspace. Overrides the top-level and display values. |
| `lone-window-width` | display or top-level `lone-window-width`, else the `fullscreen-width` in effect | The lone window width on this workspace. Overrides the top-level and display values. |

</div>

To tile only workspace 2 and send new Ghostty windows there:

```toml
default-tiling = false

[workspace.2]
tiling = true

[[rules]]
app-id = 'com.mitchellh.ghostty'
run = 'move-window-to-workspace 2'
```

### `[workspace.<number>.display.<pattern>]`

The workspace's settings while it is on a particular display, using the
[display patterns](#workspace-to-display). It takes the same keys. Keys you
leave out come from the workspace's own table. If several patterns match, the
most specific one wins, as in [`[display.<pattern>]`](#displaypattern).

```toml
[workspace.2.display.built-in]   # narrower fullscreen on the laptop screen
fullscreen-width = 0.8
```

## `[scrolling]`

Every tiled workspace is a strip of columns that can be wider than the display.
A new window opens as a new column to the right of the focused one, at
`column-width`. Columns that fit on the display are centered. When you focus a
column, the strip scrolls just enough to show all of it. See
[Columns](columns.md) for the commands that change widths.

macOS can't hide part of a window, so a column scrolled out of view is parked
at the display edge with at least 25 points still on screen. If another display
is beyond that edge, the column stays on this display, behind the columns in
view.

With focus-follows-mouse on, hovering over a column that is partly out of view
does not focus it. Click it to scroll it into view.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `column-width` | `0.5` | The width of a new column, as a share of the display inside the outer gaps. From `0.1` to `1`. |
| `preset-column-widths` | `[0.33333, 0.5, 0.66667]` | The widths `switch-preset-column-width` steps through, as shares of the display. Each from `0.1` to `1`. |

</div>

## `[gaps]`

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `inner` | `8` | Points between windows. Or `{ horizontal = 8, vertical = 6 }`. |
| `outer` | `8` | Points between windows and the display edge. Or `{ top = 44, bottom = 8, left = 8, right = 8 }`, or `outer.top = 44`. |

</div>

Gaps should be 0 or more. scuttle warns about a negative gap but uses it.

## Desktop setup on macOS 26

On macOS 26, scuttle numbers, switches and tiles the desktops you have, but it
can't create or remove them. On those versions, creating or removing desktops
from outside Mission Control can leave the Dock and the window server out of
step, so scuttle doesn't try.

To add desktops, open Mission Control (Control-Up Arrow), move the pointer to
the row of desktops at the top, and click **+**. Each display needs a desktop
for every workspace assigned to it in `[workspace-to-display]`. Unassigned
workspaces need desktops on the main display. Full-screen apps don't count.
`scuttle doctor` tells you how many each connected display needs.

If there are too few desktops, the extra workspaces have no Space and you can't
switch to them. When you add a desktop in Mission Control, scuttle uses it right
away. Lowering `workspaces` doesn't remove desktops; remove them in Mission
Control if you don't want them.

On macOS 26, scuttle explains this once at startup. **Desktop Setup…** in the
menu shows the explanation again. Workspaces without a desktop are listed in
the menu, and the menu bar shows **!** next to the workspace number.

If an older version of scuttle left desktops you can't reach, quit scuttle, run
`killall Dock`, check the desktops in Mission Control, and then open scuttle
again.

## `[workspace-to-display]`

Which display each workspace is on. Keys are workspace numbers from 1 to
`workspaces`. Values are display patterns:

- `main`: the main display.
- `secondary`: the other display, when there are two.
- Any other string: part of a display's name, as `scuttle list-displays` prints
  it.

A list of patterns is tried in order. Workspaces that aren't listed, or whose
display isn't connected, are on the main display. scuttle warns about keys like
`01` or `+1` but reads them as 1. If two keys name the same workspace, the last
one wins.

```toml
[workspace-to-display]
5 = 'secondary'         # on the side display while it's connected
4 = ['dell', 'lg']
```

When a display connects or disconnects, scuttle moves each affected workspace
to a Space on its new display, with its columns and widths. On macOS 27 and
later, it then removes Spaces that are left empty, and leaves alone leftover
Spaces that still have windows. On macOS 26, it uses the desktops that exist;
see [desktop setup](#desktop-setup-on-macos-26). A display with no workspaces
keeps one unnumbered Space. When macOS moves windows to another workspace
because a display went away, for example during sleep, scuttle puts them back
once the displays settle.

Workspaces on a display that stays connected keep their Spaces. When macOS
adds a disconnected display's Spaces to it, workspace numbers can end up out of
order in Mission Control. Reordering that display's Spaces puts them back in
numeric order, or renumbers them if `follow-space-order` is on.

The log records each display change with timestamps, the displays and their
Spaces before and after. Include it when you report a problem with docking.

## `[display.<pattern>]`

Settings for one display: `gaps`, `fullscreen-width` and
`lone-window-width`. The patterns are the same as in
[`[workspace-to-display]`](#workspace-to-display). A name pattern wins over
`main` and `secondary`, and a longer name wins over a shorter one. A width set
in [`[workspace.<number>]`](#workspacenumber) or
[`[workspace.<number>.display.<pattern>]`](#workspacenumberdisplaypattern)
wins over the display's.

```toml
[display.main]          # the display with the bar
gaps.outer.top = 44

[display.'DELL U3421WE']   # an ultrawide
fullscreen-width = 0.55
# lone-window-width = 0.75  # lone windows only; fullscreen keeps 0.55
```

## `[borders]`

A border around each window shows which one has focus.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `true` | |
| `width` | `4` | Points. Can be fractional. scuttle warns about a negative width but uses it. `inf` and `nan` fall back to the default. |
| `active-color` | `'#e1e3e4'` | The focused window's border. `'#rrggbb'` or `'#rrggbbaa'`. |
| `inactive-color` | `'#494d64'` | Every other window's border. |
| `order` | `'below'` | `'below'` draws the border behind the window. `'above'` draws it over the window; clicks pass through it. |
| `exclude-apps` | `[]` | Bundle IDs of apps whose windows get no border. |
| `rules` | `[]` | Per-window border rules, below. |

</div>

### `[[borders.rules]]`

Turn the border on or off for particular windows. A border rule uses the same
[selectors as window rules](#rules) (`app-id`, `app-id-regex`, `app-name`,
`title`, `kind`, `window-identifier` and `exclude-window-identifier`) and needs
`enabled = true` or `enabled = false` instead of `run`.

All selectors in a rule must match. If several rules match, the last one wins.
Document windows that match no rule keep their border. A rule can't give a
border to a window that `[borders] enabled = false` or `exclude-apps` leaves
out, or to a window that isn't a document window.

```toml
[[borders.rules]]
app-id = 'com.example.editor'
window-identifier = '^DocumentSettingsWindow$'
enabled = false
```

This removes the border from one auxiliary window and keeps it on the app's
document windows. `window-identifier` is the window's Accessibility identifier
(`AXIdentifier`), not its numeric window ID. To find it, run
`scuttle list-windows --all --format '%{app-name} | %{window-identifier}'`. The
patterns are case-insensitive regexes that match anywhere in the identifier; use
`^` and `$` to match all of it. A window without an identifier never matches
`window-identifier` and is never excluded by `exclude-window-identifier`.

Reloading the config with only border changes updates the borders of open
windows without moving them.

## `[focus-follows-mouse]`

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `false` | Focus the window under the pointer. Nothing happens while a mouse button is down or a menu is open, or after Cmd-Tab or a Space switch until the pointer moves to another window. |
| `delay-ms` | `100` | How long the pointer has to stay on a window before it gets focus. |

</div>

## `[swipe]`

With `enabled = true`, the trackpad swipe that switches Spaces first moves focus
between the columns of a tiled workspace. The swipe is the one macOS uses to
switch Spaces: three fingers, or four if **System Settings > Trackpad > More
Gestures > Swipe between full-screen applications** is set that way. Move your
fingers left to focus the column on the right, the same way Spaces move.

Each swipe moves focus by one column. On a workspace with one tiled window or
none, or while scuttle is disabled, the swipe goes to macOS as usual.

scuttle reads the swipe from the Dock's private events, so a macOS update can
break this. It is off by default.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `false` | Swipes left and right move focus between columns. |
| `space-switch` | `'instant'` | `'instant'`: scuttle keeps the swipe from macOS. At the last column, a swipe switches Space when you lift your fingers. `'native'`: macOS also gets every swipe, so a full, quick swipe can move focus and switch Space at once. On macOS 27 and later, `'instant'` works like `'native'`. |
| `vertical` | `false` | Also handle swipes up and down. Columns are full height, so there is no window above or below to focus, and these swipes go to macOS. |

</div>

## `[animations]`

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `true` | Windows move to their places over a short time instead of jumping. Always off while macOS's Reduce Motion is on. |
| `duration-ms` | `200` | About how long a move takes, up to 1000. `0` turns it off. |
| `resize` | `'instant'` | `'instant'`: a window takes its new size at once and only its position animates. This looks smooth in every app. `'glide'`: the size animates too. Many apps can't redraw that fast and stutter. |

</div>

Changes made to a workspace you can't see are applied without animation when
you switch to it, including with `move-window-to-workspace --follow`.

## `[drag]`

Drag the left or right edge of a tiled window to change its column's width.
Drag a tiled window onto another column and let go to swap the two columns. If
you let go anywhere else, the window goes back to its column. While scuttle is
disabled, dragging does neither.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `placeholders` | `true` | While you drag a tiled window, outline its column and the column it will swap with. |

</div>

## `[modifiers]`

Which key of each modifier pair counts in bindings. If you limit `alt` to one
side, the other Option key types special characters as usual. With
`alt = 'left'`, left Option-H focuses left and right Option-H types `˙`.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `alt` | `'both'` | `'both'`, `'left'` or `'right'`: which Option key is `alt`. |
| `ctrl` | `'both'` | The same for Control. |
| `cmd` | `'both'` | The same for Command. |
| `shift` | `'both'` | The same for Shift. |

</div>

## `[hooks]`

Commands to run on events. Each hook takes a command or a list. See
[Scripting](commands.md#scripting) for the variables `exec-and-forget` gets.

<div class="wide-table" markdown="1">

| Key | Runs |
|---|---|
| `startup` | Once, after scuttle has read the windows and displays. |
| `workspace-changing` | When scuttle starts switching workspaces, and again if you press another switch before it lands. |
| `workspace-changed` | When a display's workspace changes, or a switch gives up. With `follow-space-order`, also when reordering renumbers a display's workspaces, even if its number stays the same. |
| `focus-changed` | When focus changes, at most once every 50 ms. |
| `display-changed` | When a display connects or disconnects, about a second later, after scuttle has moved the workspaces. Sets `SCUTTLE_DISPLAYS` and `SCUTTLE_PREV_DISPLAYS`: how many displays there are now and how many there were. |

</div>

During a switch, `workspace-changed` runs once, for the workspace the switch
ends on, not for each Space it passes.

## `[[rules]]`

A rule runs commands on new windows that match it. Every matching rule runs, in
order.

Some windows float no matter what: dialogs, sheets, panels and windows that
can't be resized. Windows that can't go full screen also float while
`float-windows-without-fullscreen` is on, unless a `layout tiling` rule tiles
them. Windows an app keeps above all others, such as picture-in-picture, are
left alone and never take focus from scuttle.

A rule whose command is exactly `layout floating` or `layout tiling` decides
how the window is placed. If several do, the last one wins. All other commands
run after the window is placed.

Some windows aren't ready to be read when they open. scuttle waits up to a
second for them before running the rules, once. If you run `layout floating` or
`layout tiling` on the window during that second, your command wins over the
rules.

New windows open on the focused display, whichever display the app chose. A
rule that moves the window, such as `move-window-to-workspace`, overrides this.

<div class="wide-table" markdown="1">

| Key | |
|---|---|
| `app-id` | Bundle ID. |
| `app-id-regex` | Case-insensitive regex matched against the bundle ID. |
| `app-name` | Case-insensitive regex matched against the app's name. |
| `title` | Case-insensitive regex matched against the window title. |
| `window-identifier` | Case-insensitive regex matched against the window's Accessibility identifier (`AXIdentifier`). |
| `exclude-window-identifier` | Skip the rule if the window's Accessibility identifier matches this case-insensitive regex. |
| `kind` | `'normal'`, `'dialog'`, `'sheet'` or `'panel'`. |
| `run` | Required. A command or a list of commands. |

</div>

```toml
[[rules]]
app-id = 'com.apple.Music'
run = ['layout floating', 'move-window-to-workspace 5']
```

### Telling an app's windows apart

Some apps give their document windows and other windows the same title and
kind. Their Accessibility identifiers can still differ. In this example, the
app's settings window floats and its document windows tile on workspace 4:

```toml
[[rules]]
app-id = 'com.example.editor'
exclude-window-identifier = '^DocumentSettingsWindow$'
run = ['layout tiling', 'move-window-to-workspace 4 --follow']

[[rules]]
app-id = 'com.example.editor'
window-identifier = '^DocumentSettingsWindow$'
run = 'layout floating'
```

All selectors in a rule must match, so a window that matches
`exclude-window-identifier` skips every command in that rule. Patterns match
anywhere in the identifier; use `^` and `$` to match all of it. A window without
an identifier never matches `window-identifier` and is never excluded by
`exclude-window-identifier`. Some apps don't set identifiers.

Rules run once, when a window opens. Reloading the config doesn't run them on
open windows.

To find identifiers, run:

```sh
scuttle list-windows --all --format '%{app-name} | %{window-id} | %{window-identifier}'
```

`debug-state` also shows each window's identifier. It is empty in the list and
`null` in `debug-state` when scuttle hasn't read it yet or the app doesn't set
one.

## `[bindings]`

Key bindings. Each key maps to a command or a list of commands. scuttle takes
the key, so the app in front doesn't get it.

A key can also map to a table with `command` and `exclude-apps`, a list of
bundle IDs. While one of those apps is in front, scuttle leaves the key to it.
This is useful for terminals that use the same keys for their own panes:

```toml
[bindings]
ctrl-h = { command = 'focus left --wrap-around', exclude-apps = ['com.github.wez.wezterm', 'com.mitchellh.ghostty'] }
```

### Keys

A binding is any modifiers (`alt`, `ctrl`, `cmd`, `shift`) and one key, joined
with `-`: `alt-shift-h`, `ctrl-left`, `f5`. Key names follow the US keyboard
layout. `hyper` means all four modifiers and `meh` means all but `cmd`, so
`hyper-1` is `alt-ctrl-cmd-shift-1`.

- `a`–`z`, `0`–`9`, `f1`–`f20`
- `minus` `equal` `left-bracket` `right-bracket` `backslash` `semicolon`
  `quote` `comma` `period` `slash` `backtick` `section`
- `space` `enter` `esc` `backspace` `tab` `forward-delete` `left` `down` `up`
  `right` `page-up` `page-down` `home` `end`
- `keypad-0`–`keypad-9`, `keypad-clear` `keypad-decimal` `keypad-divide`
  `keypad-enter` `keypad-equal` `keypad-minus` `keypad-multiply` `keypad-plus`

The default bindings use `alt`, so Option can no longer type special
characters with those letters. Set `[modifiers] alt = 'left'` to keep right
Option for typing them.

## Default config

```toml
#:schema https://ahacop.github.io/scuttle/schemas/scuttle.json
# ~/.config/scuttle/scuttle.toml. Saved changes take effect at once.
# A key you leave out keeps the value shown here.
# Every key and command: https://ahacop.github.io/scuttle/configuration/

start-at-login = true
workspaces = 5                  # across all displays, one native Space each
follow-space-order = false      # true renumbers workspaces when you reorder Spaces in Mission Control
default-tiling = true           # false leaves workspaces untiled unless overridden
follow-app-activation = true    # Cmd-Tab and Dock clicks switch Spaces the fast way
float-windows-without-fullscreen = true   # progress windows, About, Calculator and the like float
block-native-fullscreen = true  # macOS full screen becomes scuttle's fullscreen on the window's workspace
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

# Display patterns: main, secondary, or part of a name as `scuttle list-displays` prints it.
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

# scuttle commands run on events. exec-and-forget gets $SCUTTLE_WORKSPACE, $SCUTTLE_PREV_WORKSPACE and $SCUTTLE_DISPLAY
# in the workspace hooks, and $SCUTTLE_DISPLAYS, $SCUTTLE_PREV_DISPLAYS (how many displays) in display-changed.
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
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
alt-4 = 'workspace 4'
alt-5 = 'workspace 5'
alt-shift-1 = 'move-window-to-workspace 1'
alt-shift-2 = 'move-window-to-workspace 2'
alt-shift-3 = 'move-window-to-workspace 3'
alt-shift-4 = 'move-window-to-workspace 4'
alt-shift-5 = 'move-window-to-workspace 5'
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
```
