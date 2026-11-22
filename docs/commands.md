---
layout: default
title: Commands
description: danky commands, the command line and socket, and scripting a bar.
permalink: /commands/
---

# Commands

Key bindings, `danky <command>` and the menu share one vocabulary. `danky help`
prints it.

<div class="wide-table" markdown="1">

| Command | |
|---|---|
| `workspace <n\|prev\|next>` | Show a workspace and focus its display. `prev`/`next` step through the focused display's and don't wrap. |
| `workspace-back-and-forth` | Switch to the previous workspace. |
| `move-window-to-workspace <n\|prev\|next> [--follow] [--window-id <id>]` | Move the focused window or the window with the given ID. With `--follow`, switch to the destination. |
| `move-window-to-display <next\|prev> [--follow] [--window-id <id>]` | Move the focused or selected window to another display's workspace. |
| `focus <left\|down\|up\|right> [--boundaries <b>] [--boundaries-action <a>]` | Focus the nearest window. `--boundaries` is `workspace` (default) or `all-monitors-outer-frame`, which continues onto the next display. `--boundaries-action` is `stop` (default), `fail`, `wrap-around-the-workspace` (`--wrap-around`) or `wrap-around-all-monitors`, which needs `all-monitors-outer-frame`. |
| `focus-monitor <left\|down\|up\|right\|next\|prev\|n>` | Focus a display. |
| `move <left\|down\|up\|right>` | Left and right swap the focused column with its neighbour, or take the window out of a shared column into a new one; up and down move it within its column. |
| `join-with <left\|down\|up\|right>` | Left and right put the focused window into the neighbouring column; up and down join it with its neighbour within the column. |
| `resize <smart\|width\|height> <+n\|-n>` | Resize by n points: `smart` and `width` change the column's width, `height` the window's share of its column. |
| `switch-preset-column-width` | Give the focused column the next of [`preset-column-widths`](configuration.md#scrolling-1), the first wider than it is now, wrapping to the narrowest, as niri does. |
| `maximize-column` | Widen the focused column to the whole display, or give a maximized column back its width. Its neighbours stay in the strip. |
| `layout <tiles\|accordion\|horizontal\|vertical\|auto\|h_tiles\|v_tiles\|h_accordion\|v_accordion\|floating\|tiling>... [--window-id <id>]` | Set the layout of the focused or selected window's container, or float/tile the window. The container is the window's [column](configuration.md#scrolling). Given several, applies the one after the current one, so `layout floating tiling` and `layout tiles accordion` toggle. Tiles the window first if it floats, so it does nothing on an empty workspace without an ID. |
| `fullscreen` | Toggle filling the workspace over the strip (not macOS full screen). [`fullscreen-width`](configuration.md#top-level) narrows and centres it. |
| `flatten-workspace-tree` | Give every window a column of its own, in order, undoing tree edits. Column widths are kept. |
| `balance-sizes` | Give every column the default width and every window an equal share of its column. |
| `retile` | Re-read windows and re-apply every layout. |
| `clear-minimum-sizes` | Forget the minimum window sizes learned for every app and re-apply every layout. |
| `mode <name>` | Switch binding mode. |
| `reload-config` | Reload the config. |
| `enable <on\|off\|toggle>` | Turn danky on or off. Off restores windows, takes their borders away and turns key bindings off too, so turn it back on from the menu or with `danky enable on`. While off, danky leaves new windows, `[[rules]]`, Spaces and workspaces alone; turning it on tiles what opened meanwhile, where it is. |
| `list-workspaces`, `list-windows`, `list-monitors`, `list-displays`, `list-modes` | See [Scripting](#scripting). `list-displays` = `list-monitors`. |
| `debug-state` | Tiling state as JSON, for bug reports. |
| `exec-and-forget <shell command>` | Run with `/bin/sh -c` without waiting. Output goes to the log. |

</div>

Workspaces are numbered across displays; see
[`[workspace-to-display]`](configuration.md#workspace-to-display). A full-screen
app's Space has no number, nor does the Space of a display without workspaces.

### If a workspace switch stalls

Switches wait for macOS to report the posted destination before sending more
input. If the log says `waiting for pending Space`, the request has timed out
but native movement is still outstanding; newer workspace commands wait behind
it. Switching and desktop arrangements can remain paused if that destination is
never observed. If they stay stuck, quit danky, restart the Dock (`killall Dock`),
then reopen danky.

### Targeting a window

`move-window-to-workspace`, `move-window-to-display` and `layout` accept `--window-id <id>` before or after their other arguments.
Without it, they act on the focused window (or the new window in a rule).
Find IDs with `danky list-windows --all`. Only managed windows on numbered
workspaces can be targeted: tiled and floating windows, not minimized, hidden,
native full-screen, system or border windows. A stale or ineligible ID is an error.
Layout commands change the selected window's container or workspace without
switching Spaces or focusing it.

With an explicit ID, `move-window-to-workspace prev` and `next` step from the
window's workspace, on its display, without wrapping. Without an ID, they step
from the focused display's current or pending workspace, as `workspace` does.
Display moves always step from the window's display.

Moving without `--follow` keeps focus where you are. Bringing a window to the
current workspace does not focus it. Use `--follow` to show its destination and
focus it, including when it is already there:

```sh
danky move-window-to-workspace 3 --window-id 12345 --follow
```

## Command line

The app binary is the CLI. `danky <command>` sends a command to the running app
and exits 1 on errors or when it isn't running. A command with nothing to do
succeeds: `move left` on a window already at the left edge prints
`move left: nothing to do` and exits 0, as `workspace 1` does on workspace 1.
CLI-only commands:

| Command | |
|---|---|
| `app` | Run the app in the foreground, logging to the terminal. |
| `doctor [--config <path>]` | Check the config and macOS settings, and that no other tiling window manager is running. |
| `recover` | Ask the running app to restore windows a crashed session left tiled. |
| `debug events\|windows` | Print window events or windows, without the app. |
| `version`, `-v`, `--version` | Print the version and build number. |

The log is `~/Library/Logs/danky.log`; attach it to bug reports.

`debug-state` reports frames as `[x, y, width, height]`. An unavailable frame,
including a transient frame during a close or minimize, is `[]`.

Scripts can skip the CLI and talk to the socket: one command per connection,
answered with `ok` or `error` and the reply.

```sh
printf 'workspace 2\n' | nc -U "$TMPDIR/danky.sock"
```

Requests are UTF-8, up to 1 MiB, and may contain newlines. After writing the
request, close the connection's writing half (`shutdown(SHUT_WR)`) and read the
reply until EOF. The CLI and macOS `nc` do this automatically. A newline alone
does not finish a request. The app rejects an incomplete request after two seconds
without incoming data, or an oversized or invalid UTF-8 request, without running it.

**Upgrading raw clients from 0.23:** sending a newline and waiting is no longer
enough; half-close the writing side to submit the command. The normal CLI and
macOS `nc` already do this.

The CLI also rejects replies over 1 MiB (including the status header), invalid
UTF-8 replies and transport failures rather than printing partial output. The
command may already have run when receiving its reply fails. Narrow large list
queries with filters or `--format`, or use a raw socket client for larger replies.

## Recovery

danky journals each window's original frame and Space before tiling it. `enable
off`, quitting, `kill` and logging out put them all back. A window that can't
be put back (display gone, app not answering) stays journaled and is tried again
by the next disable, quit or `danky recover`, unless you move it first. After a
crash, the menu offers to restore them (or `danky recover`); danky stays off
until `danky enable on`.

While Mission Control or App Exposé is detected, automatic layout writes,
animations and restacking pause. Visible workspaces apply their pending layout
when the overview closes; hidden workspaces wait until shown. Disabling or
quitting still restores the original windows during overview.

## Scripting

The queries follow [AeroSpace](https://nikitabobko.github.io/AeroSpace/commands)'s
names, flags and output, so most AeroSpace bar scripts work by swapping the
command name.

<div class="wide-table" markdown="1">

| Query | Flags | Default format |
|---|---|---|
| `list-workspaces` | `--all`, `--focused`, `--monitor <focused\|all\|n>...`, `--visible [no]`, `--empty [no]`, `--format` | `%{workspace}` |
| `list-windows` | `--all`, `--focused`, `--monitor <focused\|all\|n>...`, `--workspace <focused\|visible\|n>...`, `--app-bundle-id <id>` (or `--app-id`), `--format` | `%{window-id}%{right-padding} \| %{app-name}%{right-padding} \| %{window-title}` |
| `list-monitors` | `--focused [no]`, `--format` | `%{monitor-id}%{right-padding} \| %{monitor-name}` |
| `list-modes` | `--current` | Mode names, `main` first |

</div>

Without a display flag, `list-workspaces` and `list-windows` cover the focused
display; `list-monitors` lists every display. `list-windows` leaves out windows
an app has hidden rather than closed, such as a settings window closed with
Cmd-W that the app keeps around. Format variables:

- `%{right-padding}`, `%{newline}`, `%{tab}`
- Workspaces: `workspace`, `workspace-is-focused`, `workspace-is-visible`,
  `workspace-layout` (`scrolling`, empty on a full-screen Space), `monitor-id`, `monitor-name`, `monitor-is-main`
- Windows: `window-id`, `window-title`, `window-identifier`, `window-layout`,
  `window-parent-container-layout`, `window-is-floating`,
  `window-is-fullscreen`, `app-name`, `app-bundle-id`, `app-pid`, and the
  workspace variables

`%{window-title}` is read through Accessibility, as rules read it. A window
whose app doesn't answer, or one on a Space not shown since danky started, lists
with an empty title.

`%{monitor-is-main}` tells a bar which workspaces are on the side display.

### SketchyBar

Drive a bar from the config's [hooks](configuration.md#hooks):

```toml
[hooks]
startup = ['exec-and-forget brew services restart sketchybar']
workspace-changing = ['exec-and-forget sketchybar --trigger workspace_changing DANKY_DISPLAY=$DANKY_DISPLAY DANKY_WORKSPACE=$DANKY_WORKSPACE']
workspace-changed = ['exec-and-forget sketchybar --trigger workspace_change WORKSPACE=$DANKY_WORKSPACE']
focus-changed = ['exec-and-forget sketchybar --trigger focus_changed']
mode-changed = ['exec-and-forget sketchybar --trigger mode_changed MODE=$DANKY_MODE']
```

The workspace hooks set `DANKY_WORKSPACE` (empty on a full-screen Space),
`DANKY_PREV_WORKSPACE` and `DANKY_DISPLAY` (1-based). `workspace-changing`
fires only for danky's own switches, so draw the target there and the real
state on `workspace-changed`, which always follows. `mode-changed` sets
`DANKY_MODE` and `DANKY_PREV_MODE`; `danky list-modes --current` prints the
mode at any time. `exec-and-forget` has `danky` and Homebrew on `PATH`.

With `follow-space-order`, renumbering can send `workspace-changed` with equal
`DANKY_WORKSPACE` and `DANKY_PREV_WORKSPACE`: the workspace contents changed even
though the visible number did not. Bars should still refresh on that notification.
See [hooks](configuration.md#hooks) for switch settlement and renumbering behavior.

### Docking

For a workspace's layout per display, use
[`[workspace.<number>.display.<pattern>]`](configuration.md#workspacenumberdisplaypattern).
For anything else, `display-changed` runs once the workspaces have moved after
a display connects or disconnects. It sets `DANKY_DISPLAYS` and
`DANKY_PREV_DISPLAYS`, the number of displays now and before;
`danky list-monitors` names them.

```toml
[hooks]
display-changed = ['exec-and-forget [ "$DANKY_DISPLAYS" = 1 ] && ~/bin/laptop-mode.sh || ~/bin/desk-mode.sh']
```
