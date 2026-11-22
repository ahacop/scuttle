---
layout: default
title: Configuration
description: The TOML config file, every key and its default, and the key syntax.
permalink: /configuration/
---

# Configuration

The config file is `~/.config/scuttle/scuttle.toml`. It is created on first run
and reloaded each time it is saved. A symlink is followed, and replacing the
link also causes a reload. If the link points to a missing file, the current
config stays in use and the error is shown in the menu.

- Every key is optional. A key left out has its default value. Without
  `[bindings]` there are no key bindings, and without `[[rules]]` there are no
  rules.
- Unknown keys are errors. If the config has an error, the previous config
  stays in use and the error is shown in the menu.
- Use `scuttle doctor [--config <path>]` to check the config, including
  commands and key names.
- With the [JSON Schema](schemas/scuttle.json), completion is available in
  editors that support Taplo's `#:schema` line, such as Zed, or VS Code with
  Even Better TOML.

## Top level

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `start-at-login` | `true` | Start scuttle when you log in. |
| `workspaces` | `5` | The number of workspaces, across all displays. Each workspace is one native Space. On macOS 27 and later, Spaces are created and removed to match. On macOS 26, desktops have to be added by hand; see [desktop setup](#desktop-setup-on-macos-26). |
| `follow-space-order` | `false` | If `true`, the workspaces are renumbered when Spaces are reordered in Mission Control. On each display, the leftmost Space has the lowest number, and windows stay where they are. If `false`, each workspace keeps its number, and its windows are moved back to that number's Space the next time workspaces are arranged: on a config reload, a display change, or when a Space is removed. |
| `default-tiling` | `true` | If `false`, workspaces aren't tiled unless tiling is turned on in [`[workspace.<number>]`](#workspacenumber). |
| `follow-app-activation` | `true` | Fast Space switching when you use Cmd-Tab or the Dock. The macOS setting "When switching to an application, switch to a Space with open windows" has to be off for this. To leave some apps out, use the [`[follow-app-activation]`](#follow-app-activation) table instead. |
| `block-native-fullscreen` | `true` | When a window is put in macOS full screen (with the green button or Control-Command-F), it is moved back to its column and shown with scuttle's `fullscreen` instead, so it stays on its workspace. If `false`, macOS full screen is left as it is and the window is moved to a Space of its own. |
| `float-windows-without-fullscreen` | `true` | Float windows that can't be made full screen, such as Finder's copy progress, About This Mac and Calculator. Terminals and editors with a hidden title bar are still tiled. A `layout tiling` rule takes priority. |
| `fullscreen-width` | `1.0` | The width of a `fullscreen` window, as a share of the display width inside the outer gaps. The window is centered. From `0.1` to `1`. Can be overridden in [`[display.<pattern>]`](#displaypattern) and [`[workspace.<number>]`](#workspacenumber). |
| `lone-window-width` | the `fullscreen-width` in effect | The width of a window that is alone on its workspace and whose column fills the display, for example at column width `1` or maximized. The window is centered. From `0.1` to `1`. A value in a workspace's own table takes priority over the most specific matching display table, which takes priority over the top level. |

</div>

With `follow-space-order`, only reordering within a display is followed. Which
display a workspace belongs to is still set by `[workspace-to-display]`: if a
Space is dragged to another display, its windows are moved back to the
configured display the next time workspaces are arranged. Workspace numbers
follow position, so `[workspace.2]`, and any command or rule that names
workspace 2, applies to whichever Space is second. When the option is turned on
and the config is reloaded with `reload-config`, the current order is adopted.

## `[follow-app-activation]`

The table form of `follow-app-activation`. Use it in place of the top-level
key. Fast switching is only available while scuttle is running and enabled.
Turning it off doesn't change the macOS setting back; see
[First run](index.md#first-run).

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `true` | The same as `follow-app-activation = true`. |
| `exclude-apps` | `[]` | Bundle IDs of apps to leave out, such as a menu bar app whose popover is counted as a window. |

</div>

## `[workspace.<number>]`

Settings for one workspace. They override the top-level `default-tiling` and
widths. Workspaces are numbered from 1 across all displays. A table for a
number above `workspaces` has no effect, and a warning about it is listed by
`scuttle doctor`.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `tiling` | `default-tiling` | Whether the workspace is tiled. |
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
[display patterns](#workspace-to-display). The keys are the same. Keys left
out are taken from the workspace's own table. If several patterns match, the
most specific one is used, as in [`[display.<pattern>]`](#displaypattern).

```toml
[workspace.2.display.built-in]   # narrower fullscreen on the laptop screen
fullscreen-width = 0.8
```

## `[scrolling]`

Every tiled workspace is a strip of columns that can be wider than the display.
A new window is placed in a new column to the right of the focused one, at
`column-width`. If all columns fit on the display, the first one starts at the
left edge. When a column is
focused, the strip is scrolled just enough to show all of it. The commands for
changing widths are covered in [Columns](columns.md).

Windows can't be partly hidden on macOS, so a column scrolled out of view is
parked at the display edge with at least 25 points still on screen. If another
display is beyond that edge, the column is kept on this display, behind the
columns in view.

With focus-follows-mouse on, a column that is partly out of view isn't focused
by hovering over it. Click it to scroll it into view.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `column-width` | `0.5` | The width of a new column, as a share of the display inside the outer gaps. From `0.1` to `1`. |
| `preset-column-widths` | `[0.33333, 0.5, 0.66667]` | The widths used by `switch-preset-column-width`, as shares of the display. Each from `0.1` to `1`. |

</div>

## `[gaps]`

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `inner` | `8` | Points between windows. Or `{ horizontal = 8, vertical = 6 }`. |
| `outer` | `8` | Points between windows and the display edge. Or `{ top = 44, bottom = 8, left = 8, right = 8 }`, or `outer.top = 44`. |

</div>

Gaps should be 0 or more. A negative gap is used as written, with a warning.

## Desktop setup on macOS 26

On macOS 26, existing desktops are numbered, switched and tiled, but desktops
aren't created or removed automatically. On those versions, creating or
removing desktops outside Mission Control can leave the Dock and the window
server out of step.

To add desktops, open Mission Control (Control-Up Arrow), move the pointer to
the row of desktops at the top, and click **+**. Each display needs a desktop
for every workspace assigned to it in `[workspace-to-display]`. Unassigned
workspaces need desktops on the main display. Full-screen apps don't count.
The number needed on each connected display is listed by `scuttle doctor`.

If there are too few desktops, the extra workspaces have no Space and can't be
switched to. A desktop added in Mission Control is put to use right away.
Lowering `workspaces` doesn't remove desktops; remove them in Mission Control if
you don't want them.

On macOS 26, this is explained once at startup. To see the explanation again,
choose **Desktop Setup…** in the menu. Workspaces without a desktop are listed
in the menu, and a **!** is shown next to the workspace number in the menu bar.

If an older version of scuttle left desktops that can't be reached, quit
scuttle, run `killall Dock`, check the desktops in Mission Control, and then
open scuttle again.

## `[workspace-to-display]`

Which display each workspace belongs to. Keys are workspace numbers from 1 to
`workspaces`. Values are display patterns:

- `main`: the main display.
- `secondary`: the other display, when there are two.
- Any other string: part of a display's name, as listed by
  `scuttle list-displays`.

A list of patterns is tried in order. Workspaces that aren't listed, or whose
display isn't connected, are on the main display. Keys like `01` or `+1` are
read as 1, with a warning. If two keys name the same workspace, the last one is
used.

```toml
[workspace-to-display]
5 = 'secondary'         # on the side display while it's connected
4 = ['dell', 'lg']
```

When a display is connected or disconnected, each affected workspace is moved
to a Space on its new display, with its columns and widths. On macOS 27 and
later, Spaces left empty are then removed, and leftover Spaces that still have
windows are left alone. On macOS 26, only existing desktops are used; see
[desktop setup](#desktop-setup-on-macos-26). A display with no workspaces keeps
one unnumbered Space. Windows that end up on another workspace because a display
went away, for example during sleep, are put back once the displays have
settled.

Workspaces on a display that stays connected keep their Spaces. When a
disconnected display's Spaces are added to it, the workspace numbers can end up
out of order in Mission Control. After that display's Spaces are
reordered, the workspaces are back in numeric order, or are renumbered if
`follow-space-order` is on.

Each display change is recorded in the log with timestamps and the displays and
Spaces before and after. Include the log when you report a problem with
docking.

## `[display.<pattern>]`

Settings for one display: `gaps`, `fullscreen-width` and
`lone-window-width`. The patterns are the same as in
[`[workspace-to-display]`](#workspace-to-display). A name pattern takes
priority over `main` and `secondary`, and a longer name over a shorter one. A
width set in [`[workspace.<number>]`](#workspacenumber) or
[`[workspace.<number>.display.<pattern>]`](#workspacenumberdisplaypattern)
takes priority over the display's.

```toml
[display.main]          # the display with the bar
gaps.outer.top = 44

[display.'DELL U3421WE']   # an ultrawide
fullscreen-width = 0.55
# lone-window-width = 0.75  # lone windows only; fullscreen stays at 0.55
```

## `[borders]`

The focused window is marked by a border in a different color.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `true` | |
| `width` | `4` | Points. Can be fractional. A negative width is used as written, with a warning. `inf` and `nan` are replaced with the default. |
| `active-color` | `'#e1e3e4'` | The focused window's border. `'#rrggbb'` or `'#rrggbbaa'`. |
| `inactive-color` | `'#494d64'` | Every other window's border. |
| `order` | `'below'` | `'below'`: the border is drawn behind the window. `'above'`: it is drawn over the window, and clicks pass through it. |
| `exclude-apps` | `[]` | Bundle IDs of apps whose windows have no border. |
| `rules` | `[]` | Per-window border rules, below. |

</div>

### `[[borders.rules]]`

Turn the border on or off for particular windows. A border rule has the same
[selectors as window rules](#rules) (`app-id`, `app-id-regex`, `app-name`,
`title`, `kind`, `window-identifier` and `exclude-window-identifier`) and needs
`enabled = true` or `enabled = false` instead of `run`.

All selectors in a rule have to match. If several rules match, the last one
applies. Document windows that match no rule keep their border. A border rule
can't add a border to a window excluded by `[borders] enabled = false` or
`exclude-apps`, or to a window that isn't a document window.

```toml
[[borders.rules]]
app-id = 'com.example.editor'
window-identifier = '^DocumentSettingsWindow$'
enabled = false
```

In this example, one auxiliary window has no border, and the app's document
windows keep theirs. `window-identifier` is the window's Accessibility
identifier (`AXIdentifier`), not its numeric window ID. To find it, run
`scuttle list-windows --all --format '%{app-name} | %{window-identifier}'`. The
patterns are case-insensitive regexes matched anywhere in the identifier; use
`^` and `$` to match all of it. A window without an identifier never matches
`window-identifier` and is never excluded by `exclude-window-identifier`.

If only border settings change in a reload, the borders of open windows are
updated and the windows aren't moved.

## `[focus-follows-mouse]`

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `false` | Focus the window under the pointer. This is paused while a mouse button is down or a menu is open, and after Cmd-Tab or a Space switch until the pointer is moved to another window. |
| `delay-ms` | `100` | How long the pointer has to stay on a window before it is focused. |

</div>

## `[swipe]`

With `enabled = true`, the trackpad swipe for switching Spaces is used to move
focus between the columns of a tiled workspace first. This is the swipe set for
switching Spaces in macOS: three fingers, or four if **System Settings >
Trackpad > More Gestures > Swipe between full-screen applications** is set that
way. Swipe left to focus the column on the right, in the same direction as
Space switching.

Focus is moved by one column per swipe. On a workspace with one tiled window or
none, or while scuttle is disabled, the swipe is passed to macOS as usual.

The swipe is read from the Dock's private events, so this may stop working
after a macOS update. It is off by default.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `false` | Use swipes left and right to move focus between columns. |
| `space-switch` | `'instant'` | `'instant'`: the swipe is kept from macOS. At the last column, a swipe switches Space when your fingers are lifted. `'native'`: every swipe is also passed to macOS, so a full, quick swipe can move focus and switch Space at once. On macOS 27 and later, `'instant'` is treated as `'native'`. |
| `vertical` | `false` | Also handle swipes up and down. Columns are full height, so there is no window above or below to focus, and these swipes are passed to macOS. |

</div>

## `[animations]`

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `enabled` | `true` | Animate window moves instead of jumping. Always off while Reduce Motion is on in macOS. |
| `duration-ms` | `200` | About how long a move lasts, up to 1000. `0` turns animation off. |
| `resize` | `'instant'` | `'instant'`: a window is given its new size at once and only its position is animated. This looks smooth with every app. `'glide'`: the size is animated too, which stutters in apps that can't redraw that fast. |

</div>

Changes to a workspace that isn't visible are applied without animation when
you switch to it, including with `move-window-to-workspace --follow`.

## `[drag]`

Drag the left or right edge of a tiled window to change its column's width.
Drag a tiled window onto another column and release it to swap the two
columns. A window released anywhere else is put back in its column. While
scuttle is disabled, dragging has no effect on columns.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `placeholders` | `true` | While a tiled window is dragged, outline its column and the column it will be swapped with. |

</div>

## `[modifiers]`

`mod` is the modifier that `mod` stands for in a binding. `mod` is used in
every default binding, so when it is changed, all of them are moved to another
modifier at once. For
example, with `mod = 'ctrl-alt'`, `mod-h` is Control-Option-H. Bindings written
with `alt`, `ctrl` and so on are not affected.

The other keys set which key of each modifier pair counts in bindings. If
`alt` is limited to one side, the Option key on the other side can still be
used to type special characters. With `alt = 'left'`, left Option-H moves focus
left and right Option-H types `˙`.

<div class="wide-table" markdown="1">

| Key | Default | |
|---|---|---|
| `mod` | `'alt'` | `'alt'`, `'ctrl'`, `'cmd'`, `'shift'`, `'hyper'` or `'meh'`, or several joined by `-`, such as `'ctrl-alt'`. |
| `alt` | `'both'` | `'both'`, `'left'` or `'right'`: which Option key is `alt`. |
| `ctrl` | `'both'` | The same for Control. |
| `cmd` | `'both'` | The same for Command. |
| `shift` | `'both'` | The same for Shift. |

</div>

## `[hooks]`

Commands to run on events. Each hook is a command or a list of commands. The
variables set for `exec-and-forget` are listed under
[Scripting](commands.md#scripting).

<div class="wide-table" markdown="1">

| Key | Run |
|---|---|
| `startup` | Once, after the windows and displays have been read at startup. |
| `workspace-changing` | When a workspace switch by scuttle starts, and again if another switch is requested before it ends. |
| `workspace-changed` | When a display's workspace changes, or a switch is abandoned. With `follow-space-order`, also when a display's workspaces are renumbered after reordering, even if the displayed number is unchanged. |
| `focus-changed` | When focus changes, at most once every 50 ms. |
| `display-changed` | About a second after a display is connected or disconnected, once the workspaces have been moved. `SCUTTLE_DISPLAYS` and `SCUTTLE_PREV_DISPLAYS` are set to the number of displays now and before. |

</div>

During a switch, `workspace-changed` is run once, for the workspace the switch
ends on, not for each Space in between.

## `[[rules]]`

A rule is a set of conditions and a list of commands. When a new window matches
every condition of a rule, the rule's commands are run on it. Every matching
rule is run, in order.

Some windows are always floating: dialogs, sheets, panels and windows that
can't be resized. Windows that can't be made full screen are also floating
while `float-windows-without-fullscreen` is on, unless a `layout tiling` rule
applies to them. Windows kept above all others by their app, such as
picture-in-picture, are left alone and are never focused.

A rule whose command is exactly `layout floating` or `layout tiling` sets how
the window is placed. If several such rules match, the last one applies. All
other commands are run after the window is placed.

Some windows aren't ready to be read when they open. Rules for such a window
are run once, after a wait of up to a second. If `layout floating` or
`layout tiling` is run on the window during that wait, it takes priority over
the rules.

New windows are placed on the focused display, even if the window was opened on
another display. If a rule includes a command that moves the window, such as
`move-window-to-workspace`, the window is placed according to that command.

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

In some apps, document windows and other windows have the same title and kind.
Their Accessibility identifiers can still differ. In this example, the app's
settings window is floating and its document windows are tiled on workspace 4:

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

All selectors in a rule have to match, so for a window that matches
`exclude-window-identifier`, none of that rule's commands are run. Patterns are
matched anywhere in the identifier; use `^` and `$` to match all of it. A window
without an identifier never matches `window-identifier` and is never excluded
by `exclude-window-identifier`. Some apps don't set identifiers.

Rules are run once, when a window opens. After a config reload, they aren't run
again on windows that are already open.

To list identifiers, run:

```sh
scuttle list-windows --all --format '%{app-name} | %{window-id} | %{window-identifier}'
```

Each window's identifier is also included in `debug-state`. It is empty in the
list and `null` in `debug-state` if it hasn't been read yet or the app doesn't
set one.

## `[bindings]`

Key bindings. Each key is bound to a command or a list of commands, and any
command can be bound to any key. A `[bindings]` table in your config replaces
the default bindings completely, so only the keys listed in it are bound. A
bound key is not passed on to the app in front.

A key can also be bound to a table with `command` and `exclude-apps`, a list of
bundle IDs. While one of those apps is in front, the key is passed on to it.
This is useful for terminals that use the same keys for their own panes:

```toml
[bindings]
ctrl-h = { command = 'focus left --wrap-around', exclude-apps = ['com.github.wez.wezterm', 'com.mitchellh.ghostty'] }
```

### Keys

A binding is any modifiers (`mod`, `alt`, `ctrl`, `cmd`, `shift`) and one key,
joined with `-`: `mod-shift-h`, `ctrl-left`, `f5`. Key names follow the US
keyboard layout. `mod` is the modifier set by [`[modifiers] mod`](#modifiers),
`alt` by default. `hyper` is all four modifiers and `meh` is all but `cmd`, so
`hyper-1` is `alt-ctrl-cmd-shift-1`.

- `a`–`z`, `0`–`9`, `f1`–`f20`
- `minus` `equal` `left-bracket` `right-bracket` `backslash` `semicolon`
  `quote` `comma` `period` `slash` `backtick` `section`
- `space` `enter` `esc` `backspace` `tab` `forward-delete` `left` `down` `up`
  `right` `page-up` `page-down` `home` `end`
- `keypad-0`–`keypad-9`, `keypad-clear` `keypad-decimal` `keypad-divide`
  `keypad-enter` `keypad-equal` `keypad-minus` `keypad-multiply` `keypad-plus`

With the default `mod`, the default bindings are on Option, so Option can't be
used to type special characters with those letters. To keep right Option for
typing them, set `[modifiers] alt = 'left'`, or set `mod` to another modifier.

## Default config

```toml
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
block-native-fullscreen = true  # macOS full screen is replaced with scuttle's fullscreen on the window's workspace
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
inner = 8                       # or { horizontal = 8, vertical = 8 }
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
```
