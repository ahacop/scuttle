---
layout: default
title: Concepts
description: Workspaces, windows, the strip, displays, focus, rules and bindings.
permalink: /concepts/
---

# Concepts

## Workspace

A workspace is a native Space with a number. `workspaces = 5` gives you
workspaces 1 to 5, numbered across all displays. `workspace 3` switches to
workspace 3 in about 70 ms. Each tiled workspace has its own
[strip of columns](columns.md). On macOS 26, you have to
[add the desktops in Mission Control](configuration.md#desktop-setup-on-macos-26)
yourself. macOS 27 and later don't need this.

<figure class="wide">
{% include figures/workspaces.svg %}
<figcaption>Two displays and five workspaces. One workspace shows on each display.</figcaption>
</figure>

Each workspace is on one display: the main display, unless
[`[workspace-to-display]`](configuration.md#workspace-to-display) assigns it
to another. If that display disconnects, the workspace and its windows move to
the main display, and they move back when it reconnects.

## Window

A window is tiled, floating or fullscreen.

<figure>
{% include figures/tiled.svg %}
{% include figures/floating.svg %}
{% include figures/fullscreen.svg %}
<figcaption>Tiled, floating and fullscreen. <code>layout floating tiling</code> switches between tiled and floating. <code>fullscreen</code> turns fullscreen on and off.</figcaption>
</figure>

A tiled window is a column in the workspace's strip. A floating window stays
where you put it, above the columns. A fullscreen window covers the workspace,
or the share of it `fullscreen-width` sets; this is scuttle's fullscreen, not
macOS full screen. Dialogs, sheets and panels float on their own, and a
[rule](#rule) can float anything else.

## Strip

A tiled workspace is a row of columns called the strip. Each column holds one
window, as tall as the display, at its own width. `focus` moves between
columns and `move` reorders them. [Columns](columns.md) covers widths.

## Display

The config refers to displays by pattern: `main`, `secondary`, or part of the
display's name as `scuttle list-displays` prints it. Patterns set which display
a workspace is on, a display's gaps, and a workspace's settings while it is on
a particular display.

```toml
[workspace-to-display]
5 = 'secondary'

[display.main]
gaps.outer.top = 44

[workspace.2.display.built-in]
fullscreen-width = 0.8
```

## Focus

One window has focus, and its border shows it. `focus left` and `focus right`
move it to the next column; with `--boundaries all-monitors-outer-frame`, they
cross onto the next display. [`[focus-follows-mouse]`](configuration.md#focus-follows-mouse)
focuses the window under the pointer instead.

When the focused window closes, is minimized or its app quits, and macOS
doesn't pick another window, scuttle focuses the next column on that
workspace. Anything you do first, such as a key, a click or a Space switch,
wins. Hiding an app leaves focus to macOS.

## Rule

A rule runs commands on new windows that match it. Every matching
[`[[rules]]`](configuration.md#rules) entry runs, in order. `layout floating`
and `layout tiling` decide how the window is placed. Other commands run after
it is placed.

```toml
[[rules]]
app-id = 'com.apple.Music'
run = ['layout floating', 'move-window-to-workspace 5']
```

## Bindings

Key bindings are in [`[bindings]`](configuration.md#bindings). Each key runs a
command or a list of commands.

```toml
[bindings]
alt-r = 'switch-preset-column-width'
alt-shift-j = 'move-window-to-workspace next --follow'
```

The menu lists the common commands with their keys.
