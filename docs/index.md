---
layout: default
title: Documentation
description: A scrolling tiling window manager for macOS that leaves System Integrity Protection on.
permalink: /
---

# scuttle: scrolling tiling on native Spaces, with SIP left on

```
$ scuttle workspace 3
$ scuttle list-windows --workspace 3
4211 | Ghostty | ~
4388 | Safari  | scuttle
$ scuttle switch-preset-column-width
```

scuttle is a tiling window manager for macOS. Each workspace is a native Space,
and switching between them takes about 70 ms instead of half a second. Windows
on a workspace are arranged as a strip of full-height columns, one window per
column, in the style of [niri](https://github.com/YaLTeR/niri). It has preset
column widths, focus borders, a TOML config, and a `scuttle` command for
scripts and status bars. It doesn't inject code into the Dock.

macOS still draws every window. scuttle moves and resizes windows through the
Accessibility API, and animates them by moving them a step at a time. macOS
can't clip a window, so a column scrolled out of view hangs over the edge of
the display.

scuttle is early software. Its author uses it every day on macOS 27, but expect
bugs.

> **Private APIs.** macOS has no public API to switch Spaces quickly or move a
> window to another Space, so scuttle uses a synthetic Dock swipe and some
> private SkyLight functions. A macOS update can break them.

## Requirements

- macOS 15 or later, on Apple silicon or Intel. Intel Macs are supported up to
  macOS 26.
- Accessibility permission. scuttle asks for it the first time it runs.

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

`just install` builds and signs `build/scuttle.app` and links the command into
`~/.local/bin`. Sign it with the same identity every time (list yours with
`security find-identity -p codesigning`). macOS ties the Accessibility
permission to the signature, so an unsigned build loses it on every rebuild.

## First run

On first run, scuttle writes `~/.config/scuttle/scuttle.toml` and asks for
Accessibility permission. It also offers once to turn off the macOS setting
"When switching to an application, switch to a Space with open windows" in
System Settings > Desktop & Dock > Mission Control. With that setting off,
Cmd-Tab and Dock clicks switch Spaces quickly instead of sliding, as long as
scuttle is running. You can say no.

This is a macOS setting, so it stays off after you quit or disable scuttle. If
switching to an app with Cmd-Tab, the Dock or a launcher shows only its menu bar
and not its window, turn the setting back on.

Also turn off "Automatically rearrange Spaces based on most recent use" in the
same place. Otherwise workspace numbers change on their own. `scuttle doctor`
warns while it is on.

The menu bar shows the current workspace number. The menu has the common
commands with their keys, and lists the other key bindings under Other Key
Bindings. `scuttle doctor` checks the config and the macOS settings scuttle
needs.

Run only one tiling window manager at a time. If AeroSpace, Amethyst, yabai or
KiwiDesk is also running, they undo each other's work. scuttle shows `!` in the
menu bar and names the one to quit.

### Magnet and Rectangle

scuttle keeps tiled windows in their columns, even when another app moves them.
To place a window with Magnet or Rectangle, float it first with
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

- Docking has been tested with virtual displays more than with real ones.
  Switching workspaces on a display the pointer isn't on can make the pointer
  flicker.
- On macOS 26, scuttle can't create or remove desktops. Add them in
  [Mission Control](configuration.md#desktop-setup-on-macos-26). On macOS 27
  and later, scuttle keeps one Space per workspace and leaves extra Spaces that
  still have windows alone.
- Some apps refuse some sizes, such as Safari's minimum width or Terminal's
  character grid. scuttle lays out around them, but windows can overlap or
  leave gaps. scuttle learns an app's minimum size when a window stays the same
  size after two different resizes, so an app's first window may overlap its
  neighbor until then. Clear Saved Minimum Sizes in the menu forgets what it
  learned.
- macOS can't focus a window on another Space, so scuttle switches Space first.

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
