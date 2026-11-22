---
layout: default
title: Commands
description: Every command, the command line, the socket, and scripting a status bar.
permalink: /commands/
---

# Commands

Key bindings, rules, hooks, the menu and `scuttle <command>` all use the same
commands. `scuttle help` lists them.

<div class="wide-table" markdown="1">

| Command | |
|---|---|
| `workspace <n\|prev\|next>` | Switch to a workspace and focus its display. `prev` and `next` move through the focused display's workspaces and stop at the first and last. |
| `workspace-back-and-forth` | Switch to the previous workspace. |
| `move-window-to-workspace <n\|prev\|next> [--follow] [--window-id <id>]` | Move the focused window, or the window with that ID, to a workspace. With `--follow`, switch there too. |
| `move-window-to-display <next\|prev> [--follow] [--window-id <id>]` | Move the window to the workspace on another display. |
| `focus <left\|down\|up\|right> [--boundaries <b>] [--boundaries-action <a>]` | Focus the next column in that direction. `up` and `down` only go to another display. `--boundaries` is `workspace` (the default) or `all-monitors-outer-frame`, which lets focus continue onto the next display. `--boundaries-action` says what happens at the edge: `stop` (the default), `fail`, `wrap-around-the-workspace` (or `--wrap-around`), or `wrap-around-all-monitors`, which needs `all-monitors-outer-frame`. |
| `focus-monitor <left\|down\|up\|right\|next\|prev\|n>` | Focus a display. |
| `move <left\|right>` | Swap the focused column with the one next to it. |
| `resize width <+n\|-n>` | Make the focused column n points wider or narrower. |
| `switch-preset-column-width` | Set the focused column to the next width in [`preset-column-widths`](configuration.md#scrolling) that is wider than it is now. After the widest, go back to the narrowest. |
| `maximize-column` | Make the focused column as wide as the display. Run it again to restore its width. The other columns stay in the strip. |
| `layout <floating\|tiling>... [--window-id <id>]` | Float the window, or tile it in a new column. `layout floating tiling` switches between the two. |
| `fullscreen` | Show the focused window over the whole workspace, or turn that off. This is not macOS full screen. [`fullscreen-width`](configuration.md#top-level) makes it narrower. |
| `balance-sizes` | Set every column to `column-width`. |
| `clear-minimum-sizes` | Forget the minimum window sizes scuttle has learned, and lay out every workspace again. |
| `reload-config` | Reload the config file. |
| `enable <on\|off\|toggle>` | Turn scuttle on or off. Off puts windows back where they were before scuttle tiled them, removes borders, and turns off key bindings, so turn it back on from the menu or with `scuttle enable on`. While off, scuttle ignores new windows, rules, Spaces and workspaces. When you turn it on, it tiles the windows that opened in the meantime, on the workspaces they are on. |
| `list-workspaces`, `list-windows`, `list-monitors`, `list-displays` | See [Scripting](#scripting). `list-displays` is the same as `list-monitors`. |
| `debug-state` | Print scuttle's state as JSON, for bug reports. |
| `exec-and-forget <shell command>` | Run a shell command with `/bin/sh -c` and don't wait for it. Its output goes to the log. |

</div>

Workspaces are numbered across all displays; see
[`[workspace-to-display]`](configuration.md#workspace-to-display). Full-screen
app Spaces have no number, and neither does the Space of a display with no
workspaces.

### If a workspace switch gets stuck

scuttle waits for macOS to confirm each Space switch before it sends the next
one. If the log says `waiting for pending Space`, a switch timed out and later
switches are waiting for it. If switching stays stuck, quit scuttle, run
`killall Dock`, and open scuttle again.

### Targeting a window

`move-window-to-workspace`, `move-window-to-display` and `layout` take
`--window-id <id>` before or after their other arguments. Without it, they act
on the focused window, or on the new window when run from a rule. Find window
IDs with `scuttle list-windows --all`.

Only tiled and floating windows on numbered workspaces can be targeted. Minimized,
hidden, native full-screen and system windows can't. An ID that is out of date or
can't be targeted is an error. These commands don't switch Spaces or change focus.

With an ID, `move-window-to-workspace prev` and `next` count from the window's
own workspace, on its display, and stop at the first and last. Without an ID,
they count from the focused display's workspace, the same as `workspace`.
`move-window-to-display` always counts from the window's display.

Without `--follow`, focus stays where it is, even if you bring a window to the
workspace you are on. With `--follow`, scuttle switches to the window's
workspace and focuses it:

```sh
scuttle move-window-to-workspace 3 --window-id 12345 --follow
```

## Command line

The `scuttle` command sends a command to the running app. It exits with status
1 if the command fails or the app isn't running. A command that has nothing to
do still succeeds: `move left` on the leftmost column prints
`move left: nothing to do` and exits 0.

These commands only work on the command line:

| Command | |
|---|---|
| `app` | Run the app in the foreground and log to the terminal. |
| `doctor [--config <path>]` | Check the config and the macOS settings scuttle needs, and check that no other tiling window manager is running. |
| `recover` | Put back windows that a crashed session left tiled. |
| `debug events\|windows` | Print window events or the list of windows, without the app. |
| `version`, `-v`, `--version` | Print the version and build number. |

The log is `~/Library/Logs/scuttle.log`. Attach it to bug reports.

`debug-state` gives frames as `[x, y, width, height]`. A frame scuttle couldn't
read, for example while a window is closing, is `[]`.

### The socket

Scripts can send commands to the socket directly. Send one command per
connection. The reply starts with `ok` or `error`.

```sh
printf 'workspace 2\n' | nc -U "$TMPDIR/scuttle.sock"
```

A request is UTF-8 text up to 1 MiB and can contain newlines. After writing it,
close the writing half of the connection (`shutdown(SHUT_WR)`) and read the
reply until the connection closes. The `scuttle` command and macOS `nc` already
do this; a newline alone doesn't end a request. scuttle rejects a request that
is too large or isn't valid UTF-8, or that stops arriving for two seconds,
without running it.

The `scuttle` command also rejects replies over 1 MiB and replies that aren't
valid UTF-8, instead of printing part of them. In that case the command may
still have run. To keep list replies small, use filters or `--format`.

## Recovery

Before scuttle tiles a window, it records the window's frame and Space. When you
run `enable off`, quit, kill scuttle or log out, it puts every window back. If a
window can't be put back, for example because its display is gone or its app
doesn't respond, scuttle tries again the next time you disable or quit it, or
run `scuttle recover`, unless you have moved the window yourself.

After a crash, the menu offers to put windows back, and so does
`scuttle recover`. scuttle stays off until you run `scuttle enable on`.

While Mission Control or App Exposé is open, scuttle doesn't move windows. It
applies the changes when you close it, to visible workspaces at once and to the
others when you switch to them. Disabling or quitting still puts windows back
while Mission Control is open.

## Scripting

The list commands use [AeroSpace](https://nikitabobko.github.io/AeroSpace/commands)'s
names, flags and output format, so most AeroSpace bar scripts work after you
change the command name.

<div class="wide-table" markdown="1">

| Query | Flags | Default format |
|---|---|---|
| `list-workspaces` | `--all`, `--focused`, `--monitor <focused\|all\|n>...`, `--visible [no]`, `--empty [no]`, `--format` | `%{workspace}` |
| `list-windows` | `--all`, `--focused`, `--monitor <focused\|all\|n>...`, `--workspace <focused\|visible\|n>...`, `--app-bundle-id <id>` (or `--app-id`), `--format` | `%{window-id}%{right-padding} \| %{app-name}%{right-padding} \| %{window-title}` |
| `list-monitors` | `--focused [no]`, `--format` | `%{monitor-id}%{right-padding} \| %{monitor-name}` |

</div>

Without a display flag, `list-workspaces` and `list-windows` only cover the
focused display. `list-monitors` lists every display. `list-windows` leaves out
windows an app has hidden instead of closing, such as a settings window you
closed with Cmd-W that the app keeps in memory.

Format variables:

- `%{right-padding}`, `%{newline}`, `%{tab}`
- Workspaces: `workspace`, `workspace-is-focused`, `workspace-is-visible`,
  `workspace-layout` (always `scrolling`; empty on a full-screen Space),
  `monitor-id`, `monitor-name`, `monitor-is-main`
- Windows: `window-id`, `window-title`, `window-identifier`, `window-layout`
  (`tiling`, `floating` or `fullscreen`), `window-parent-container-layout`
  (always empty), `window-is-floating`, `window-is-fullscreen`, `app-name`,
  `app-bundle-id`, `app-pid`, and the workspace variables

scuttle reads `%{window-title}` through Accessibility. It is empty if the app
doesn't answer, or if the window is on a Space you haven't visited since
scuttle started.

`%{monitor-is-main}` tells a bar which workspaces are on the main display.

### SketchyBar

Update a bar from the config's [hooks](configuration.md#hooks):

```toml
[hooks]
startup = ['exec-and-forget brew services restart sketchybar']
workspace-changing = ['exec-and-forget sketchybar --trigger workspace_changing SCUTTLE_DISPLAY=$SCUTTLE_DISPLAY SCUTTLE_WORKSPACE=$SCUTTLE_WORKSPACE']
workspace-changed = ['exec-and-forget sketchybar --trigger workspace_change WORKSPACE=$SCUTTLE_WORKSPACE']
focus-changed = ['exec-and-forget sketchybar --trigger focus_changed']
```

The workspace hooks set `SCUTTLE_WORKSPACE` (empty on a full-screen Space),
`SCUTTLE_PREV_WORKSPACE` and `SCUTTLE_DISPLAY` (counting from 1).
`workspace-changing` only runs for switches scuttle makes, so use it to show
the workspace being switched to, and use `workspace-changed`, which always
follows, to show where the switch ended. `exec-and-forget` has `scuttle` and
Homebrew on its `PATH`.

With `follow-space-order`, `workspace-changed` can run with the same
`SCUTTLE_WORKSPACE` and `SCUTTLE_PREV_WORKSPACE` when reordering changed which
Space has that number. A bar should still redraw.

### Docking

For per-display workspace settings, use
[`[workspace.<number>.display.<pattern>]`](configuration.md#workspacenumberdisplaypattern).
For anything else, use the `display-changed` hook. It runs after a display
connects or disconnects and scuttle has moved the workspaces, and sets
`SCUTTLE_DISPLAYS` and `SCUTTLE_PREV_DISPLAYS` to the number of displays now
and before. `scuttle list-monitors` lists them by name.

```toml
[hooks]
display-changed = ['exec-and-forget [ "$SCUTTLE_DISPLAYS" = 1 ] && ~/bin/laptop-mode.sh || ~/bin/desk-mode.sh']
```
