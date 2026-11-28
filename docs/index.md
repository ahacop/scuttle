---
layout: default
title: Documentation
description: A scrolling tiling window manager for macOS.
permalink: /
---

<img class="app-icon" src="{{ '/assets/icon.png' | relative_url }}" alt="scuttle's app icon: a red crab carrying a window" width="96" height="96">

# scuttle: scrolling tiling on native Spaces

```
$ scuttle workspace 3
$ scuttle list-windows --workspace 3
4211 | Ghostty | ~
4388 | Safari  | scuttle
$ scuttle switch-preset-column-width
```

scuttle is a tiling window manager for macOS. Each workspace is a native Space,
and switching between them takes about 70 ms instead of half a second. The
windows on a workspace are arranged as a strip of full-height columns, one
window per column, in the style of [niri](https://github.com/YaLTeR/niri).
Columns have preset widths, the focused window has a colored border, settings
are kept in a TOML file, and a `scuttle` command is available for scripts and
status bars. No code is injected into the Dock, so System Integrity Protection
can stay on.

scuttle isn't a compositor, and windows are drawn the usual way. Windows are moved and resized through the
Accessibility API, and animation is done by moving a window a step at a time.
Windows can't be clipped on macOS, so a column scrolled out of view is left
partly over the edge of the display.

scuttle is early software. Its author uses it every day on macOS 27, but expect
bugs.

> **Private APIs.** macOS has no public API for switching Spaces quickly or for
> moving a window to another Space, so a synthetic Dock swipe and some private
> SkyLight functions are used instead. They may stop working after a macOS
> update.

## Requirements

- macOS 15 or later, on Apple silicon or Intel. Intel Macs are supported up to
  macOS 26.
- Accessibility permission. You are asked for it the first time scuttle is opened.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask ahacop/tap/scuttle
```

Or download `scuttle.app.zip` from the
[latest release](https://github.com/ahacop/scuttle/releases/latest), unzip it
and move `scuttle.app` to Applications. To update, choose Check for Updates in
the menu.

### From source

You need Swift 6 and [`just`](https://github.com/casey/just).

```sh
git clone https://github.com/ahacop/scuttle.git && cd scuttle
IDENTITY="Apple Development: Your Name (TEAMID)" just install
open build/scuttle.app
```

With `just install`, `build/scuttle.app` is built and signed, and the `scuttle`
command is linked into `~/.local/bin`. Sign it with the same identity every
time (list yours with `security find-identity -p codesigning`). The
Accessibility permission is tied to the app's signature, so an unsigned build
loses it on every rebuild.

## First run

On first run, `~/.config/scuttle/scuttle.toml` is created and Accessibility
permission is requested. You are also offered, once, the option to turn off the
macOS setting "When switching to an application, switch to a Space with open
windows" in System Settings > Desktop & Dock > Mission Control. With that
setting off and scuttle running, switching apps with Cmd-Tab or the Dock moves
to the app's Space quickly instead of sliding. You can decline.

This is a macOS setting, so it stays off after scuttle is quit or disabled. If
only an app's menu bar appears when you switch to it with Cmd-Tab, the Dock or
a launcher, and its window doesn't, turn the setting back on.

Also turn off "Automatically rearrange Spaces based on most recent use" in the
same place. Otherwise the workspace numbers change on their own. A warning is
listed by `scuttle doctor` while it is on.

The current workspace number is shown in the menu bar. The common commands and
their keys are in the menu, and the other key bindings are listed under Other
Key Bindings. Use `scuttle doctor` to check the config and the macOS settings
scuttle needs.

Run only one tiling window manager at a time. If AeroSpace, Amethyst, yabai or
KiwiDesk is also running, each one's changes are undone by the other. A `!` is
shown in the menu bar, and the one to quit is named in the menu.

### Magnet and Rectangle

Tiled windows are kept in their columns, even after being moved with another
app. To place a window with Magnet or Rectangle, float it first with
`scuttle layout floating`, or turn scuttle off with `scuttle enable off`. Use
`scuttle layout tiling` or `scuttle enable on` to go back. To make a window
cover its workspace, use [`scuttle fullscreen`](commands.md).

## Uninstall

Quit scuttle and delete:

- the app
- `~/.config/scuttle`
- `~/Library/Application Support/scuttle`
- `~/Library/Logs/scuttle.log`

Then run `defaults delete com.ahacop.scuttle` and remove scuttle from
Accessibility and Login Items in System Settings. To get the sliding Space
switch back:

```sh
defaults write com.apple.dock workspaces-auto-swoosh -bool true && killall Dock
```

## Known limits

- Docking has been tested with virtual displays more than with real ones. The
  pointer can flicker when you switch workspaces on a display the pointer isn't
  on.
- On macOS 26, desktops aren't created or removed automatically. Add them in
  [Mission Control](configuration.md#desktop-setup-on-macos-26). On macOS 27
  and later, there is one Space per workspace, and extra Spaces that still have
  windows are left alone.
- Some apps have size limits, such as Safari's minimum width or Terminal's
  character grid. A column is as wide as its window turns out to be: when a
  window comes back wider or narrower than its column asked, its neighbors
  move to where it ends, a moment after the first layout. The answer is kept
  for that width only, and the window is asked again whenever its column's
  width is changed. Ask Windows for Their Widths Again in the menu asks every
  window again.
- A window on another Space can't be focused directly, so its Space is switched
  to first.

## Credits

- [dinky](https://github.com/mikker/Dinky) (MIT) by Mikkel Malmberg. scuttle is
  a fork of dinky with everything but the scrolling layout removed.
- [niri](https://github.com/YaLTeR/niri): the scrolling layout, preset column
  widths and maximizing columns.
- [yabai](https://github.com/asmvik/yabai) (MIT): SkyLight function
  signatures, window filtering, focus and event handling. Only the parts that
  work with SIP on.
- [mimi](https://github.com/y3owk1n/mimi) (MIT): the fast Dock swipe and the
  SkyLight symbol lookup.
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) (MIT): the key syntax
  and command names.
- [JankyBorders](https://github.com/FelixKratz/JankyBorders) (GPL-3.0): studied
  for the borders, no code used.
- [Tuna](https://tunaformac.com): an earlier Dock swipe.
- [bobrwm](https://github.com/bobrwm/bobrwm) (MIT): creating Spaces.

MIT licensed.
