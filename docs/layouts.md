---
layout: default
title: Layouts
description: One layout, a scrolling strip of one-window columns after niri. Column widths, presets and maximizing.
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

Each column is one window, as tall as the display. `focus` and `move` go left
and right between columns (Alt-H / Alt-L, with Shift to move).

Workspaces stack top to bottom, as in niri. Alt-J and Alt-K go to the
workspace below and above (`workspace next` and `prev`), and Alt-Shift-J and
Alt-Shift-K take the focused column there and follow it
(`move-window-to-workspace next --follow`). They stop at the first and last
workspace. Each workspace is a native Space, so macOS's own overview still
shows them side by side.

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

macOS's own full screen would put the window on a Space of its own, outside
every workspace, so scuttle brings it straight back and shows it with
`fullscreen` instead. `block-native-fullscreen = false` leaves it to macOS.

Windows glide to their new places in `[animations] duration-ms`. An app has to
redraw its contents for every size it is given, and few keep up with one a
frame, so by default (`resize = 'instant'`) a window takes its new size at once
and only its position glides. `resize = 'glide'` animates the size as well.

## Floating

`layout floating` takes a window out of the strip, where it stays as you put
it; `layout tiling` gives it a column again, and `layout floating tiling`
toggles (Alt-V). Dialogs, sheets and panels float on their own.
