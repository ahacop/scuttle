<img src="docs/assets/icon.png" alt="scuttle" width="128">

# scuttle

A scrolling tiling window manager for macOS that leaves System Integrity
Protection on. Each window is placed in a full-height column on a strip that can
be scrolled, one window per column. Press `Alt-R` to step the focused column
through preset widths (a third, a half and two thirds by default), or `Alt-F` to
maximize it.

[Documentation](https://ahacop.github.io/scuttle/)

## Quick start

```sh
brew install --cask ahacop/tap/scuttle
```

Open scuttle and grant Accessibility permission when asked. New windows are
tiled as they open.

- `scuttle workspace 3`: Switch to workspace 3.
- `scuttle switch-preset-column-width`: Set the focused column to the next preset width.
- `scuttle maximize-column`: Make the focused column as wide as the display, and back.
- `scuttle doctor`: Check the config, the macOS settings scuttle needs, and that no other tiling window manager is running.

**macOS 26:** Desktops have to be added in Mission Control (Control-Up Arrow).
Existing desktops are numbered, switched and tiled, but desktops are only
created and removed automatically on macOS 27 and later. Add enough desktops on
each display for the workspaces assigned to it. Missing desktops are listed by
`scuttle doctor`.

More:

- [Concepts](docs/concepts.md) and [Columns](docs/columns.md)
- [Configuration](docs/configuration.md)
- [Commands](docs/commands.md)
- [Border development](docs/border-development.md): the native comparison
  preview and regression tests for window borders

## Inspiration

- [niri](https://github.com/YaLTeR/niri), the scrollable-tiling Wayland
  compositor. scuttle's layout, column widths and workspace stacking are based
  on it.
- [dinky](https://github.com/mikker/Dinky) by Mikkel Malmberg. scuttle is a fork
  of dinky 0.30 with everything I didn't want removed: the dwindle, fixed and
  master layouts, drag-to-split, binding modes, and default bindings that shadow
  macOS shortcuts. What's left is dinky's scrolling layout, native Spaces
  workspaces and SIP-on approach.

MIT licensed.
