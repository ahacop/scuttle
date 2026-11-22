<img src="docs/assets/icon.png" alt="danky" width="128">

# danky

> oh wow. you moved a rectangle.

A scrolling tiling window manager for macOS, after niri, that leaves System
Integrity Protection on. Forked from [dinky](https://github.com/mikker/Dinky) by
Mikkel Malmberg and cut down to its scrolling layout, with niri's column
widths: `Alt-R` steps the focused column through preset widths (a third, a half,
two thirds by default) and `Alt-F` maximizes it.

[Documentation](docs/index.md)

## Quick start

Open danky and grant Accessibility when asked. Windows tile as they open.

- `danky workspace 3`: Switch to workspace 3.
- `danky switch-preset-column-width`: Step the focused column to the next preset width.
- `danky maximize-column`: Widen the focused column to the whole display, and back.
- `danky layout accordion`: Stack the focused column.
- `danky doctor`: Check the config, the macOS settings danky needs, and that no other tiler is running.

**macOS 26:** Create and remove desktops in Mission Control (Control–↑). danky
numbers, switches and tiles existing desktops, but automatic desktop creation
and removal require macOS 27 or later. Add enough desktops on each display for
your configured workspaces; `danky doctor` reports shortages.

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

MIT licensed.
