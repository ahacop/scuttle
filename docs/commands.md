---
layout: default
title: Commands
description: Every command, the command line, the socket, and scripting a status bar.
permalink: /commands/
---

# Commands

The same commands are used in key bindings, rules, hooks, the menu and
`scuttle <command>`. Run `scuttle help` to list them.

<div class="wide-table" markdown="1">

| Command | |
|---|---|
| `workspace <n\|prev\|next>` | Switch to a workspace and focus its display. With `prev` and `next`, the focused display's workspaces are stepped through, without wrapping past the first or last. |
| `workspace-back-and-forth` | Switch to the previous workspace. |
| `move-window-to-workspace <n\|prev\|next> [--follow] [--window-id <id>]` | Move the focused window, or the window with that ID, to a workspace. With `--follow`, also switch to it. |
| `move-window-to-display <next\|prev> [--follow] [--window-id <id>]` | Move the window to the workspace on another display. |
| `focus <left\|down\|up\|right> [--boundaries <b>] [--boundaries-action <a>]` | Move focus to the next column in that direction. With `up` and `down`, focus can only move to another display. `--boundaries` is `workspace` (the default) or `all-monitors-outer-frame`, with which focus can continue onto the next display. With `--boundaries-action`, choose what happens at the edge: `stop` (the default), `fail`, `wrap-around-the-workspace` (or `--wrap-around`), or `wrap-around-all-monitors`, which requires `all-monitors-outer-frame`. |
| `focus-monitor <left\|down\|up\|right\|next\|prev\|n>` | Focus a display. |
| `move <left\|right>` | Swap the focused column with the one next to it. |
| `resize width <+n\|-n>` | Make the focused column n points wider or narrower. |
| `switch-preset-column-width` | Set the focused column to the next width in [`preset-column-widths`](configuration.md#scrolling) that is wider than its current width. After the widest, the narrowest is next. |
| `maximize-column` | Make the focused column as wide as the display. Run it again to restore the previous width. The other columns stay in the strip. |
| `layout <floating\|tiling>... [--window-id <id>]` | Float the window, or tile it in a new column. Use `layout floating tiling` to switch between the two. |
| `fullscreen` | Show the focused window over the whole workspace, or turn that off. This is not macOS full screen. Its width is set by [`fullscreen-width`](configuration.md#top-level). |
| `balance-sizes` | Set every column to `column-width`. |
| `clear-minimum-sizes` | Clear the recorded minimum window sizes and lay out every workspace again. |
| `reload-config` | Reload the config file. |
| `enable <on\|off\|toggle>` | Turn scuttle on or off. When it is off, windows are put back where they were before they were tiled, borders are removed, and key bindings are turned off, so turn it back on from the menu or with `scuttle enable on`. While it is off, new windows, rules, Spaces and workspaces are ignored. When it is turned back on, windows opened in the meantime are tiled on the workspaces they are on. |
| `list-workspaces`, `list-windows`, `list-monitors`, `list-displays` | See [Scripting](#scripting). `list-displays` is the same as `list-monitors`. |
| `debug-state` | Print scuttle's state as JSON, for bug reports. |
| `exec-and-forget <shell command>` | Run a shell command with `/bin/sh -c` without waiting for it. Its output is written to the log. |

</div>

Workspaces are numbered across all displays; see
[`[workspace-to-display]`](configuration.md#workspace-to-display). Full-screen
app Spaces have no number, and neither does the Space of a display with no
workspaces.

### If a workspace switch gets stuck

Each Space switch has to be confirmed before the next one is sent. If
the log contains `waiting for pending Space`, a switch has timed out and later
switches are queued behind it. If switching is still stuck, quit scuttle, run
`killall Dock`, and open scuttle again.

### Targeting a window

`--window-id <id>` can be given to `move-window-to-workspace`,
`move-window-to-display` and `layout`, before or after their other arguments.
Without it, the focused window is used, or the new window when the command is
run from a rule. To list window IDs, run `scuttle list-windows --all`.

Only tiled and floating windows on numbered workspaces can be targeted.
Minimized, hidden, native full-screen and system windows can't. An ID that is
out of date or can't be targeted is an error. Spaces and focus are not changed
when a window is targeted by ID.

With an ID, `prev` and `next` in `move-window-to-workspace` are counted from the
window's own workspace, on its display, without wrapping. Without an ID, they
are counted from the focused display's workspace, as with `workspace`. For
`move-window-to-display`, displays are always counted from the window's
display.

Without `--follow`, focus stays where it is, even when a window is brought to
the current workspace. With `--follow`, the window's workspace is switched to
and the window is focused:

```sh
scuttle move-window-to-workspace 3 --window-id 12345 --follow
```

## Command line

With `scuttle <command>`, a command is sent to the running app. The exit status
is 1 if the command fails or the app isn't running. A command with nothing to
do still counts as a success: for `move left` on the leftmost column,
`move left: nothing to do` is printed and the exit status is 0.

These commands are only available on the command line:

| Command | |
|---|---|
| `app` | Run the app in the foreground, with its log printed to the terminal. |
| `doctor [--config <path>]` | Check the config and the macOS settings scuttle needs, and check that no other tiling window manager is running. |
| `recover` | Put back windows left tiled by a session that crashed. |
| `debug events\|windows` | Print window events or the list of windows, without the app. |
| `version`, `-v`, `--version` | Print the version and build number. |

The log is `~/Library/Logs/scuttle.log`. Attach it to bug reports.

In `debug-state`, frames are written as `[x, y, width, height]`. A frame that
couldn't be read, for example while a window is closing, is written as `[]`.

### The socket

Commands can also be sent to the socket directly, one command per connection.
The reply starts with `ok` or `error`.

```sh
printf 'workspace 2\n' | nc -U "$TMPDIR/scuttle.sock"
```

A request is UTF-8 text up to 1 MiB and can contain newlines. After writing it,
close the writing half of the connection (`shutdown(SHUT_WR)`) and read the
reply until the connection is closed. When the `scuttle` command or macOS
`nc` is used, this happens automatically. A newline alone does not mark the end of a request.
A request is rejected without being run if it is larger than 1 MiB, isn't valid
UTF-8, or has had no new data for two seconds.

With the `scuttle` command, replies over 1 MiB and replies that aren't valid
UTF-8 are rejected instead of being printed in part. In that case, the command
may still have been run. To keep list replies small, use filters or `--format`.

## Recovery

Before a window is tiled, its frame and Space are recorded. When you run
`enable off`, quit, kill scuttle or log out, every window is put back. If a
window can't be put back, for example because its display is gone or its app
is unresponsive, it is tried again the next time scuttle is disabled or quit,
or when you run `scuttle recover`, unless you have moved the window yourself.

After a crash, putting the windows back is offered in the menu and with
`scuttle recover`. scuttle stays off until you run `scuttle enable on`.

While Mission Control or App Exposé is open, windows aren't moved. The changes
are applied after it is closed: to visible workspaces right away, and to the
others when you switch to them. Windows are still put back if scuttle is
disabled or quit while Mission Control is open.

## Scripting

The list commands have the same names, flags and output format as
[AeroSpace](https://nikitabobko.github.io/AeroSpace/commands)'s, so most
AeroSpace bar scripts work once the command name is changed.

<div class="wide-table" markdown="1">

| Query | Flags | Default format |
|---|---|---|
| `list-workspaces` | `--all`, `--focused`, `--monitor <focused\|all\|n>...`, `--visible [no]`, `--empty [no]`, `--format` | `%{workspace}` |
| `list-windows` | `--all`, `--focused`, `--monitor <focused\|all\|n>...`, `--workspace <focused\|visible\|n>...`, `--app-bundle-id <id>` (or `--app-id`), `--format` | `%{window-id}%{right-padding} \| %{app-name}%{right-padding} \| %{window-title}` |
| `list-monitors` | `--focused [no]`, `--format` | `%{monitor-id}%{right-padding} \| %{monitor-name}` |

</div>

Without a display flag, only the focused display is included in
`list-workspaces` and `list-windows`. Every display is included in
`list-monitors`. Windows that are hidden instead of closed, such as a
settings window closed with Cmd-W but kept in memory, are left out of
`list-windows`.

Format variables:

- `%{right-padding}`, `%{newline}`, `%{tab}`
- Workspaces: `workspace`, `workspace-is-focused`, `workspace-is-visible`,
  `workspace-layout` (always `scrolling`; empty on a full-screen Space),
  `monitor-id`, `monitor-name`, `monitor-is-main`
- Windows: `window-id`, `window-title`, `window-identifier`, `window-layout`
  (`tiling`, `floating` or `fullscreen`), `window-parent-container-layout`
  (always empty), `window-is-floating`, `window-is-fullscreen`, `app-name`,
  `app-bundle-id`, `app-pid`, and the workspace variables

`%{window-title}` is read through Accessibility. It is empty if the app is
unresponsive, or if the window is on a Space that hasn't been visited since
scuttle started.

Use `%{monitor-is-main}` in a bar to find which workspaces are on the main
display.

### SketchyBar

To update a bar, use the config's [hooks](configuration.md#hooks):

```toml
[hooks]
startup = ['exec-and-forget brew services restart sketchybar']
workspace-changing = ['exec-and-forget sketchybar --trigger workspace_changing SCUTTLE_DISPLAY=$SCUTTLE_DISPLAY SCUTTLE_WORKSPACE=$SCUTTLE_WORKSPACE']
workspace-changed = ['exec-and-forget sketchybar --trigger workspace_change WORKSPACE=$SCUTTLE_WORKSPACE']
focus-changed = ['exec-and-forget sketchybar --trigger focus_changed']
```

In the workspace hooks, `SCUTTLE_WORKSPACE` (empty on a full-screen Space),
`SCUTTLE_PREV_WORKSPACE` and `SCUTTLE_DISPLAY` (counting from 1) are set.
`workspace-changing` is only run for switches made by scuttle, so use it to
show the workspace being switched to. Use `workspace-changed`, which is always
run afterwards, to show where the switch ended. `scuttle` and Homebrew are on
the `PATH` of `exec-and-forget` commands.

With `follow-space-order`, `workspace-changed` can be run with the same
`SCUTTLE_WORKSPACE` and `SCUTTLE_PREV_WORKSPACE` when reordering has changed
which Space has that number. Redraw the bar in that case too.

### Docking

For per-display workspace settings, use
[`[workspace.<number>.display.<pattern>]`](configuration.md#workspacenumberdisplaypattern).
For anything else, use the `display-changed` hook. It is run after a display is
connected or disconnected and the workspaces have been moved.
`SCUTTLE_DISPLAYS` and `SCUTTLE_PREV_DISPLAYS` are set to the number of
displays now and before. To list the displays by name, run
`scuttle list-monitors`.

```toml
[hooks]
display-changed = ['exec-and-forget [ "$SCUTTLE_DISPLAYS" = 1 ] && ~/bin/laptop-mode.sh || ~/bin/desk-mode.sh']
```
