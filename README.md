<img src="docs/assets/icon.png" alt="scuttle" width="128">

# scuttle

A scrolling tiling window manager for macOS that leaves System Integrity
Protection on. Windows open as columns on a strip you scroll through, one window
per column at full height. `Alt-R` steps the focused column through preset
widths (a third, a half, two thirds by default) and `Alt-F` maximizes it.

[Documentation](docs/index.md)

## Quick start

Open scuttle and grant Accessibility when asked. Windows tile as they open.

- `scuttle workspace 3`: Switch to workspace 3.
- `scuttle switch-preset-column-width`: Step the focused column to the next preset width.
- `scuttle maximize-column`: Widen the focused column to the whole display, and back.
- `scuttle doctor`: Check the config, the macOS settings scuttle needs, and that no other tiler is running.

**macOS 26:** Create and remove desktops in Mission Control (Control–↑). scuttle
numbers, switches and tiles existing desktops, but automatic desktop creation
and removal require macOS 27 or later. Add enough desktops on each display for
your configured workspaces; `scuttle doctor` reports shortages.

Learn more:

- [Concepts](docs/concepts.md) and [Layouts](docs/layouts.md)
- [Configuration](docs/configuration.md)
- [Commands](docs/commands.md)

Window rules can match or exclude Accessibility identifiers to distinguish auxiliary
windows from documents with the same title. See [window rules](docs/configuration.md#rules).

Window borders use a subtle 5% optical thickening at rounded corner midpoints,
tapering back to the configured width at the straight edges.

Per-window [`[[borders.rules]]`](docs/configuration.md#bordersrules) can hide auxiliary-window borders independently of floating/tiling, including by Accessibility `AXIdentifier`. Border-only reloads update existing windows without changing their placement.

See [border development](docs/border-development.md) for the native comparison preview and regression tests.

## Inspiration

- [niri](https://github.com/YaLTeR/niri), the scrollable-tiling Wayland
  compositor. scuttle's layout, column widths and workspace stacking follow it.
- [dinky](https://github.com/mikker/Dinky) by Mikkel Malmberg. scuttle is a fork
  of dinky 0.30 with everything I didn't want removed: the dwindle, fixed and
  master layouts, drag-to-split, binding modes, and default bindings that shadow
  macOS shortcuts. What's left is dinky's scrolling layout, native Spaces
  workspaces and SIP-on approach.

MIT licensed.
