---
layout: default
title: Documentation
description: A tiling window manager for macOS that leaves System Integrity Protection on.
permalink: /
---

<img class="app-icon" src="{{ '/assets/icon.png' | relative_url }}" alt="scuttle's icon: a sketched crab scuttling sideways with a window held up in one claw" width="128" height="128">

# Tiling on native Spaces, SIP left on.

<p class="tagline">oh wow. you moved a rectangle.</p>

<pre><code>$ scuttle workspace 3
$ scuttle list-windows --workspace 3
4211 | Ghostty | ~
4388 | Safari  | scuttle
$ scuttle switch-preset-column-width <span class="cursor">█</span></code></pre>

scuttle tiles the windows on each native Space and switches Spaces in about 70 ms
instead of half a second. It has one layout, a scrolling strip of columns
of one window each after niri, with preset column widths, focus borders, a TOML
config and a `scuttle` command line for scripts and bars. Nothing is injected into
the Dock.

It is not a compositor: macOS still draws every window. Windows glide to their
tiles by being moved there, frame by frame, and a column scrolled out of view
hangs off the display edge, since nothing can clip it.

Status: early, in daily use by its author on macOS 27. Expect rough edges.

> **Private APIs.** macOS has no public way to switch Spaces quickly or move a
> window between them, so scuttle uses a synthetic Dock swipe and a few private
> SkyLight calls. A macOS update can break them.

## Requirements

- macOS 15 or later on Apple silicon or Intel. Intel Macs support macOS through 26.
  Developed and used daily on macOS 27.
- Accessibility permission. The first run asks.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask ahacop/tap/scuttle
```

Or download `scuttle.app.zip` from the
[latest release](https://github.com/ahacop/scuttle/releases/latest), unzip it
and move `scuttle.app` to Applications. Either way, scuttle updates itself:
the menu has Check for Updates.

### From source

Needs Swift 6 and [`just`](https://github.com/casey/just).

```sh
git clone https://github.com/ahacop/scuttle.git && cd scuttle
IDENTITY="Apple Development: Your Name (TEAMID)" just install
open build/scuttle.app
```

`just install` builds and signs `build/scuttle.app` and links the CLI into
`~/.local/bin`. Sign with a stable identity
(`security find-identity -p codesigning`): macOS ties the Accessibility grant
to the signature, so ad-hoc builds lose it on every rebuild.

## First run

scuttle writes `~/.config/scuttle/scuttle.toml`, asks for Accessibility, and offers
once to turn off "When switching to an application, switch to a Space with
open windows" (Desktop & Dock > Mission Control). With that off, Cmd-Tab and
Dock clicks switch Spaces the fast way instead of sliding while scuttle is running
and enabled. Saying no is fine. This is a persistent macOS preference: quitting
or disabling scuttle does not turn it back on. If activating an app with Quicksilver,
Cmd-Tab or the Dock shows only its menu bar instead of switching to its Space,
turn the setting back on in System Settings > Desktop & Dock > Mission Control.

The menu bar shows the current workspace. Its menu has the everyday commands
(workspaces, focus, move, column widths, floating and fullscreen), each with
the key bound to it, and lists the bindings it doesn't
cover under Other Key Bindings. `scuttle doctor` checks the config and the macOS
settings scuttle depends on.

Turn off "Automatically rearrange Spaces based on most recent use" in the same
place, or workspace numbers move around; `scuttle doctor` warns while it's on.

Run one tiling window manager at a time. With AeroSpace, Amethyst, yabai or
KiwiDesk also running, each undoes the other's layouts; scuttle shows a `!` in the
menu bar and says which one to quit.

### Magnet and Rectangle

To snap a window with Magnet or Rectangle, first float it with
`scuttle layout floating`, or disable scuttle with `scuttle enable off` before snapping.
scuttle keeps tiled windows in their layout, including after another app moves or
resizes them; a snapping command does not automatically float a window. Snapping
tools are not included in the warning about other tiling window managers.
Use `scuttle layout tiling` to tile the window again, or `scuttle enable on` to resume
tiling after disabling scuttle. For a workspace-filling window managed by scuttle,
use [`scuttle fullscreen`](commands.md) instead.

## Uninstall

Quit scuttle, delete the app, `~/.config/scuttle`,
`~/Library/Application Support/scuttle` and `~/Library/Logs/scuttle.log`, run
`defaults delete com.ahacop.scuttle`, and remove it from Accessibility and Login
Items. To get the Cmd-Tab slide back:

```sh
defaults write com.apple.dock workspaces-auto-swoosh -bool true && killall Dock
```

## Known limits

- Multi-display docking is tested with virtual displays; physical docking
  coverage is limited. Switching a display the pointer is not on may flicker
  the pointer.
- On macOS 26, [create and remove desktops in Mission Control](configuration.md#desktop-setup-on-macos-26).
  scuttle numbers, switches and tiles existing desktops, but does not create or
  remove them. Automatic desktop management requires macOS 27 or later; there,
  scuttle keeps one Space per workspace and leaves leftovers with windows alone.
- Apps refuse some sizes (Safari's minimum width, Terminal's grid). scuttle lays
  out around them, but tiles can overlap or leave gaps. A window has a minimum
  size once it comes back at the same size for two different sizes asked, so
  the first window of an app may overlap its neighbor until its tile changes
  size. scuttle remembers each app's minimum size; Clear Saved Minimum Sizes in
  the menu forgets them.
- macOS cannot focus a window on another Space, so scuttle switches first.

## Credits

- [dinky](https://github.com/mikker/Dinky) (MIT) by Mikkel Malmberg: scuttle is
  a fork of it, cut down to the scrolling layout.
- [niri](https://github.com/YaLTeR/niri): the scrolling layout, preset column
  widths and maximized columns.
- [yabai](https://github.com/asmvik/yabai) (MIT): SkyLight signatures, window
  filtering, focus and event handling. SIP-on paths only.
- [mimi](https://github.com/y3owk1n/mimi) (MIT): the fast Dock swipe and the
  SkyLight symbol lookup.
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) (MIT): key syntax,
  commands and the accordion.
- [JankyBorders](https://github.com/FelixKratz/JankyBorders) (GPL-3.0): borders,
  studied only.
- [Tuna](https://tunaformac.com): an earlier Dock swipe.
- [bobrwm](https://github.com/bobrwm/bobrwm) (MIT): creating Spaces.

MIT licensed.
