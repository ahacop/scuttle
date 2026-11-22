#!/usr/bin/env bash
# Times a border redraw (as during an animated resize) against a plain move, around the frontmost window.
# Draws a border there for about two seconds. Usage: scripts/border-bench.sh
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d)/border-bench"
clang -O2 -fobjc-arc -ISources/ScuttlePrivate/include -ISources/ScuttlePrivate Sources/ScuttlePrivate/*.m scripts/border-bench.m \
  -framework AppKit -framework ApplicationServices -framework Carbon \
  -F/System/Library/PrivateFrameworks -framework SkyLight -o "$out"
"$out"
