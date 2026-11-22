---
layout: default
title: Layouts
description: One layout, a scrolling strip of columns after niri. Column widths, presets, maximizing, tiles and accordion.
permalink: /layouts/
---

# Layouts

Every tiled workspace is a **scrolling strip**: a row of columns wider than
the display, after niri. A new window opens as a column right of the focused
one, `column-width` wide. Focusing a column scrolls just far enough to show it
whole. Columns that fit, a lone one too, are centred.

<figure class="wide">
{% include figures/scrolling.svg %}
<figcaption>Columns 2 and 3 in view. macOS can't clip a window, so 1 and 4 hang off the edges with a sliver left on.</figcaption>
</figure>

`focus` and `move` go left and right between columns, up and down within one.
`join-with` puts the window into the column beside it.

```toml
[scrolling]
column-width = 0.5
preset-column-widths = [0.33333, 0.5, 0.66667]
```

## Column widths

Each column keeps its own width, a share of the display.

| Command | Default key | Does |
|---|---|---|
| `switch-preset-column-width` | Alt-R | The next of `preset-column-widths` wider than the column is now, wrapping to the narrowest. |
| `maximize-column` | Alt-F | The whole display, and back to the width it had. Its neighbours stay in the strip. |
| `resize width +n` / `-n` | Alt-= / Alt-- | n points wider or narrower. |
| `fullscreen` | Alt-Shift-F | Shows the window over the strip, which keeps its widths. |

Dragging a column's left or right edge sets its width too.

## Tiles and accordion

A column holds one window or several. Several share it as tiles, top to
bottom, or as an accordion, which gives it to the focused window, with the
others peeking out by up to `padding` points on each side. Peeks shrink in
narrow columns to leave usable content and respect recorded window minima.
Focus a neighbour and it comes to the front.

<figure>
{% include figures/tiles.svg %}
{% include figures/accordion-h.svg %}
{% include figures/accordion-v.svg %}
<figcaption>The same three windows as tiles, as an accordion, and as a vertical one.</figcaption>
</figure>

A column also has an axis: `horizontal`, `vertical`, or `auto`, the longer
side of its rectangle. `layout vertical` turns it.

## Switching

<div class="wide-table" markdown="1">

| Command | Changes | Of |
|---|---|---|
| `layout tiles\|accordion` | the mode | the focused window's column. |
| `layout horizontal\|vertical\|auto` | the axis | the same column. |
| `layout floating\|tiling` | tiled or not | the focused window. |
| `flatten-workspace-tree` | every column back to one window each | the workspace. |

</div>

Given several names, `layout` applies the one after the current, so
`layout tiles accordion` toggles. The keys, defaults and edge cases are in
[Configuration](configuration.md) and [Commands](commands.md).
