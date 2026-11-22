---
layout: default
title: Concepts
description: Workspaces, windows, the strip, displays, focus, rules and bindings.
permalink: /concepts/
---

# Concepts

## Workspace

A workspace is a native Space with a number. With `workspaces = 5`, there are
workspaces 1 to 5, numbered across all displays. Switching to workspace 3 with
`workspace 3` takes about 70 ms. Each tiled workspace has its own
[strip of columns](columns.md). On macOS 26, the desktops have to be
[added in Mission Control](configuration.md#desktop-setup-on-macos-26) by hand.
On macOS 27 and later, this step isn't needed.

<figure class="wide">
{% include figures/workspaces.svg %}
<figcaption>Two displays and five workspaces. One workspace is visible on each display.</figcaption>
</figure>

Each workspace belongs to one display: the main display, unless
[`[workspace-to-display]`](configuration.md#workspace-to-display) assigns it
to another. If that display is disconnected, the workspace and its windows are
moved to the main display, and they are moved back when it is reconnected.

## Window

A window is tiled, floating or fullscreen.

<figure>
{% include figures/tiled.svg %}
{% include figures/floating.svg %}
{% include figures/fullscreen.svg %}
<figcaption>Tiled, floating and fullscreen. <code>layout floating tiling</code> switches a window between tiled and floating. <code>fullscreen</code> turns fullscreen on and off.</figcaption>
</figure>

A tiled window is a column in the workspace's strip. A floating window stays
where you put it, above the columns. A fullscreen window covers the workspace,
or the part of its width set by `fullscreen-width`. This is scuttle's
fullscreen, not macOS full screen. Dialogs, sheets and panels are always
floating, and other windows can be made to float with a [rule](#rule).

## Strip

A tiled workspace is a row of columns called the strip. Each column contains
one window, is as tall as the display, and has its own width. Use `focus` to
move between columns and `move` to reorder them. Widths are covered in
[Columns](columns.md).

## Display

In the config, displays are named by pattern: `main`, `secondary`, or part of
the display's name as listed by `scuttle list-displays`. Patterns are used to
assign workspaces to displays, to set a display's gaps, and to set a
workspace's settings while it is on a particular display.

```toml
[workspace-to-display]
5 = 'secondary'

[display.main]
gaps.outer.top = 44

[workspace.2.display.built-in]
fullscreen-width = 0.8
```

## Focus

One window at a time has focus. The focused window is marked by a different
border color. Use `focus left` and `focus right` to move focus to the next
column. With `--boundaries all-monitors-outer-frame`, focus can also move onto
the next display. With [`[focus-follows-mouse]`](configuration.md#focus-follows-mouse)
on, the window under the pointer is focused instead.

If the focused window is closed or minimized, or its app quits, and no other
window has become the key window, the next column on that workspace is
focused. A key press, click or Space switch made before that takes priority.
When an app is hidden, focus is left to macOS.

## Rule

A rule is a set of conditions and a list of commands. When a new window
matches every condition of a [`[[rules]]`](configuration.md#rules) entry, the
entry's commands are run on it. All matching entries are run, in order.
`layout floating` and `layout tiling` set how the window is placed. Other
commands are run after it is placed.

```toml
[[rules]]
app-id = 'com.apple.Music'
run = ['layout floating', 'move-window-to-workspace 5']
```

## Bindings

Key bindings are set in [`[bindings]`](configuration.md#bindings). Each key is
bound to a command or a list of commands. `mod` is the modifier set by
[`[modifiers] mod`](configuration.md#modifiers), Option by default.

```toml
[bindings]
mod-r = 'switch-preset-column-width'
mod-shift-j = 'move-window-to-workspace next --follow'
```

The common commands and their keys are listed in the menu.
