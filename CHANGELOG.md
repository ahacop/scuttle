# Changelog

## Unreleased

- Borders stay on their windows while they animate: a border is placed half a display frame after its window was moved instead of at the start of the frame, when the window had often not moved yet. On screen a moving window's border is now 1 to 6 points off on average, where it was 5 to 17.
- A border no longer trails behind as a thin line when its window changes width: its top and bottom are stretched to the window's width on every frame and redrawn once the window has arrived, instead of being redrawn on every frame.
- Much less work while windows animate, about a third of what 0.5 did, so commands and key presses during an animation are handled sooner.
- Dragging a tiled window by its title bar no longer freezes scuttle for about a second the first time the outlines of its tile and of the tile under the pointer show: borders kept still meanwhile, and a drop made then took a second to act.

## 0.5

- Smoother column swaps and small width changes: a window whose size changes by 16 points or less takes its new size at once while it glides, instead of being redrawn on every frame for a difference too small to see.
- Less work while windows animate: keeping borders on moving windows takes about half the time it did, so commands and key presses during an animation are handled sooner.
- A change of focus redraws the two borders that change colour in place, and asks the window server which window has focus once instead of twice.

## 0.4

- Borders keep up with moving windows: while a window animates, its border is placed on every frame where the window is, instead of trailing it by several frames.
- Smoother animations: they run at the display's full frame rate, take the configured `duration-ms` instead of trailing on for twice as long, and neighbouring columns no longer pull apart while they move.
- A border no longer flashes in the menu bar while its window is resized.
- Commands no longer wait up to half a second when they follow an animation closely, and borders stay closer to moving windows.
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
