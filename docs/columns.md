---
layout: default
title: Columns
description: The scrolling strip of columns, column widths, maximizing and floating.
permalink: /columns/
---

# Columns

Every tiled workspace is a strip of columns that can be wider than the
display, as in [niri](https://github.com/YaLTeR/niri). Each column contains one
window and is as tall as the display. A new window is placed in a new column to
the right of the focused one, at `column-width`. When a column is focused, the
strip is scrolled just enough to show all of it. If all columns fit on the
display, the first one starts at the left edge, including a single column.

<figure class="wide">
{% include figures/scrolling.svg %}
<figcaption>Columns 2 and 3 are in view. Windows can't be clipped on macOS, so columns 1 and 4 are left partly over the display edges.</figcaption>
</figure>

The keys on this page are the default bindings, with
[`mod`](configuration.md#modifiers) set to Alt.

Press <kbd>Alt-H</kbd> or <kbd>Alt-L</kbd> to move focus to the column on the
left or right. Add <kbd>Shift</kbd> to move the column instead.

Workspaces are stacked top to bottom, as in niri. Press <kbd>Alt-J</kbd> or
<kbd>Alt-K</kbd> to switch to the workspace below or above. Press
<kbd>Alt-Shift-J</kbd> or <kbd>Alt-Shift-K</kbd> to move the focused column to
that workspace and switch to it. There is no wrapping past the first or last workspace. Each workspace is
a native Space, so they still appear side by side in Mission Control.

```toml
[scrolling]
column-width = 0.5
preset-column-widths = [0.33333, 0.5, 0.66667]
```

## Column widths

Each column has its own width, as a share of the display.

| Command | Key | |
|---|---|---|
| `switch-preset-column-width` | <kbd>Alt-R</kbd> | Set the column to the next width in `preset-column-widths` that is wider than its current width. After the widest, the narrowest is next. |
| `maximize-column` | <kbd>Alt-F</kbd> | Make the column as wide as the display. Run it again to restore the previous width. The other columns stay in the strip. |
| `resize width +n` / `-n` | <kbd>Alt-=</kbd> <kbd>Alt--</kbd> | Make the column n points wider or narrower. The default bindings use 50. |
| `fullscreen` | <kbd>Alt-Shift-F</kbd> | Show the window over the whole workspace. The columns keep their widths. |

A column's width can also be changed by dragging the left or right edge of its
window.

In macOS full screen, a window is moved to a Space of its own, outside every
workspace. scuttle leaves it there: its column is closed, and it gets a new
column, right of the focused one, when it leaves full screen. Set
`block-native-fullscreen = true` to keep windows on their workspaces: a window
put in macOS full screen is then put back in its column and shown with
`fullscreen` instead.

A switch between a workspace and a window in macOS full screen slides across,
as it does without scuttle, whether it is made with Cmd-Tab, the Dock or a
`workspace` command. The slide lasts about `[animations] duration-ms`, and
longer when workspaces lie between the two: they pass by on the way. Switches
between workspaces are still instant. On macOS 26 and earlier, the slide is the
short one macOS draws for every switch.

Window moves are animated over `[animations] duration-ms`. Each new size
requires a redraw of the window's contents, and in many apps that redraw takes
longer than one frame. So by default (`resize = 'instant'`), a window is given its new size at once and only
its position is animated. With `resize = 'glide'`, the size is animated too, unless it changes by 16 points or
less: such a change is too small to see as a glide and would still cost a redraw every frame.

## Floating

Use `layout floating` to take a window out of the strip. A floating window
stays where you put it. Use `layout tiling` to put it back in a new column, or
`layout floating tiling` (<kbd>Alt-V</kbd>) to switch between the two. Dialogs, sheets and panels
are always floating.
