---
layout: default
title: Columns
description: The scrolling strip of columns, column widths, maximizing and floating.
permalink: /columns/
---

# Columns

Every tiled workspace is a strip of columns that can be wider than the
display, as in [niri](https://github.com/YaLTeR/niri). Each column holds one
window and is as tall as the display. A new window opens as a new column to the
right of the focused one, at `column-width`. When you focus a column, the strip
scrolls just enough to show all of it. Columns that fit on the display are
centered, including a single column.

<figure class="wide">
{% include figures/scrolling.svg %}
<figcaption>Columns 2 and 3 are in view. macOS can't clip a window, so columns 1 and 4 hang over the display edges.</figcaption>
</figure>

<kbd>Alt-H</kbd> and <kbd>Alt-L</kbd> focus the column to the left and right.
Add <kbd>Shift</kbd> to move the column instead.

Workspaces are stacked top to bottom, as in niri. <kbd>Alt-J</kbd> and
<kbd>Alt-K</kbd> switch to the workspace below and above. <kbd>Alt-Shift-J</kbd>
and <kbd>Alt-Shift-K</kbd> move the focused column to that workspace and switch
to it. They stop at the first and last workspace. Each workspace is a native
Space, so Mission Control still shows them side by side.

```toml
[scrolling]
column-width = 0.5
preset-column-widths = [0.33333, 0.5, 0.66667]
```

## Column widths

Each column has its own width, as a share of the display.

| Command | Key | |
|---|---|---|
| `switch-preset-column-width` | <kbd>Alt-R</kbd> | Set the column to the next width in `preset-column-widths` that is wider than it is now. After the widest, go back to the narrowest. |
| `maximize-column` | <kbd>Alt-F</kbd> | Make the column as wide as the display. Press again to restore its width. The other columns stay in the strip. |
| `resize width +n` / `-n` | <kbd>Alt-=</kbd> <kbd>Alt--</kbd> | Make the column n points wider or narrower. The default bindings use 50. |
| `fullscreen` | <kbd>Alt-Shift-F</kbd> | Show the window over the whole workspace. The columns keep their widths. |

You can also drag the left or right edge of a window to change its column's
width.

macOS full screen would move the window to a Space of its own, outside every
workspace. scuttle moves it back and shows it with `fullscreen` instead. Set
`block-native-fullscreen = false` to let macOS handle it.

When windows move, they animate over `[animations] duration-ms`. Apps have to
redraw for every new size, and many can't do that every frame. So by default
(`resize = 'instant'`) a window takes its new size at once and only its
position animates. `resize = 'glide'` animates the size too.

## Floating

`layout floating` takes a window out of the strip. It stays where you put it.
`layout tiling` puts it back in a new column, and `layout floating tiling`
(<kbd>Alt-V</kbd>) switches between the two. Dialogs, sheets and panels always
float.
