# Changelog

## Unreleased

Forked from [dinky](https://github.com/mikker/Dinky) 0.30 and renamed danky.

- Scrolling is the only layout. The dwindle, fixed and master layouts, `workspace-layout`, `swap-with-master`, `default-layout`, per-workspace `layout`, `[master]` and drag-to-split (`[drag] split-trigger`, `split-delay-ms`) are gone.
- `switch-preset-column-width` (Alt-R) steps the focused column through `[scrolling] preset-column-widths`, niri's thirds by default.
- `maximize-column` (Alt-F) widens the focused column to the whole display and back. `fullscreen` moves to Alt-Shift-F, `layout floating tiling` to Alt-V.
- A lone column keeps its width, centred, instead of filling the display. `column-width` defaults to `0.5`.
- No Sparkle update feed: the menu has no Check for Updates until one is configured.
