#!/bin/sh
# Renders banner.html to docs/assets/banner.png, the docs' 1200×630 link-preview image. Needs Google Chrome and a
# network connection for the DM Mono font.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out="$here/../../docs/assets/banner.png"
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
"$chrome" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=1200,630 --virtual-time-budget=5000 \
  --screenshot="$out" "file://$here/banner.html" 2>/dev/null
echo "wrote $out"
