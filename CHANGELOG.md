# Changelog

## Unreleased

- **Edit Config…** in the menu opens the config file in your text editor.
- Borders stay visible and resize with their windows during animations, instead of disappearing until the window arrives.
- `scuttle version` prints the app's version when run through Homebrew's `scuttle` command, instead of `dev (0)`.

## 0.3

- Columns that fit on the display start at the left edge instead of being centered, so the first column stays in place when a width change makes the strip fit.

## 0.2

- New setting `[modifiers] mod`: the modifier for every default binding, `alt` by default. In a binding, `mod` stands for it, as in `mod-h`. With `mod = 'ctrl-alt'`, `mod-h` is Control-Option-H. The default bindings in new configs are written with `mod`. Bindings written with `alt` are unchanged, so existing configs work as before.
- The manual at [ahacop.github.io/scuttle](https://ahacop.github.io/scuttle/) is rewritten, and has a light, dark and system theme switch.

## 0.1

Forked from [dinky](https://github.com/mikker/Dinky) 0.30 and renamed scuttle.

- Scrolling is the only layout. The dwindle, fixed and master layouts, `workspace-layout`, `swap-with-master`, `default-layout`, per-workspace `layout`, `[master]` and drag-to-split (`[drag] split-trigger`, `split-delay-ms`) are gone.
- `switch-preset-column-width` (Alt-R) steps the focused column through `[scrolling] preset-column-widths`, niri's thirds by default.
- `maximize-column` (Alt-F) widens the focused column to the whole display and back. `fullscreen` moves to Alt-Shift-F, `layout floating tiling` to Alt-V.
- A lone column keeps its width, centred, instead of filling the display. `column-width` defaults to `0.5`.
- Fewer default bindings: Ctrl-Left/Right (macOS's own Space switching is back), Alt-6…9 and Alt-Shift-6…9 (past the 5 default workspaces) and Alt-Shift-N (`move-window-to-display next`) are gone. Add them to `[bindings]` to keep them.
- Releases are signed, notarized and published at [ahacop/scuttle](https://github.com/ahacop/scuttle/releases). Install with `brew install --cask ahacop/tap/scuttle`; Check for Updates in the menu installs new versions.
