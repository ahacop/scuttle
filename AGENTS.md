# scuttle

A scrolling tiling window manager for macOS, in Swift (SwiftPM). The manual is in `docs/`; read the page for a
feature before describing or testing it. `docs/concepts.md`, `docs/columns.md` and `docs/commands.md` say what
exists.

## What scuttle does and does not do

Check claims about features against this list and the docs, not against other tiling window managers.

- A workspace is a native Space. A tiled workspace is a **strip of columns**, niri style.
- **One window per column, each as tall as the display.** There are no stacked windows, no rows within a column
  and no window heights to change. Nothing moves or resizes vertically within a workspace.
- "Workspaces are stacked top to bottom" is about `workspace next/prev` (Alt-J/K). It is not window stacking.
- A window is **tiled, floating or fullscreen**. `fullscreen` is scuttle's own: the window covers the workspace
  (or `fullscreen-width` of it) and stays on it. **macOS native full screen is not a layout**: by default such a
  window is left on its full-screen Space, outside every workspace, with no column until it comes back. With
  `block-native-fullscreen = true` it is put back on its workspace and shown with `fullscreen` instead.
- Width is the only size a command changes: `switch-preset-column-width`, `maximize-column`, `resize width ±n`,
  `balance-sizes`, and dragging a window's left or right edge.
- Columns are reordered with `move left|right` and by dragging a window onto another column.
- `focus left|right` moves between columns and scrolls the strip just enough to show the focused one. Columns
  scrolled out of view hang over the display's edge, since macOS can't clip windows.
- Other things that move windows: a window opening or closing (neighbours make or fill room), `layout
  floating|tiling`, `move-window-to-workspace`, `move-window-to-display`, a display connecting or disconnecting.
  Changes to a workspace that isn't visible are applied without animation.
- Switching workspaces is instant. A switch between a window in macOS native full screen and the workspace next to
  its Space slides, over about `duration-ms` (macOS 27 and later). To or from any other workspace it is instant too.
- Animation: `[animations] duration-ms` (200) and `resize` (`'instant'` by default: sizes snap, positions glide;
  `'glide'`: sizes glide too, except changes of 16 points or less). Off with Reduce Motion.

## Working here

- `just build`, `just test` (Swift tests and `scripts/tests`), `IDENTITY=<hash> scripts/bundle.sh` for a signed
  bundle that keeps its Accessibility grant.
- Animation performance is measured with `scripts/anim` (see its README). Recordings take over the screen and need
  it unlocked and left alone.
- Commit and push only when asked.
