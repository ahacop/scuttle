#!/usr/bin/env bash
# Builds build/danky.app and signs it with a stable identity, so the Accessibility grant survives rebuilds.
# Usage: scripts/bundle.sh [--debug]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0}"
BUILD="${BUILD:-1}"
# Set IDENTITY to your own signing identity (security find-identity -p codesigning). Ad-hoc (-) works, but
# macOS drops the Accessibility grant on every rebuild.
IDENTITY="${IDENTITY:--}"
SIGN_FLAGS="${SIGN_FLAGS:-}"  # release packaging adds --options runtime --timestamp
CONFIG=release
[[ "${1:-}" == "--debug" ]] && CONFIG=debug

BUILD_FLAGS=(-c "$CONFIG" --jobs 4)
if [[ "$CONFIG" == release ]]; then
  BUILD_FLAGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_FLAGS[@]}"

APP=build/danky.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/danky" "$APP/Contents/MacOS/danky"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$APP/Contents/Info.plist"

# The app icon: Resources/Danky.icon (Icon Composer) compiled into Assets.car and an icns fallback.
ICON_OUT="$(mktemp -d)"
xcrun actool "$PWD/Resources/Danky.icon" --compile "$ICON_OUT" --platform macosx --minimum-deployment-target 15.0 \
  --app-icon Danky --include-all-app-icons --output-partial-info-plist "$ICON_OUT/partial.plist" >/dev/null
mkdir -p "$APP/Contents/Resources"
cp "$ICON_OUT/Assets.car" "$ICON_OUT/Danky.icns" "$APP/Contents/Resources/"
plutil -replace CFBundleIconFile -string Danky "$APP/Contents/Info.plist"
plutil -replace CFBundleIconName -string Danky "$APP/Contents/Info.plist"
rm -rf "$ICON_OUT"

# Sparkle.framework from the resolved SwiftPM artifact; the linker rpath finds it here.
SPARKLE_SRC="$(find .build/artifacts -maxdepth 6 -path '*macos-arm64_x86_64/Sparkle.framework' | head -1)"
[[ -n "$SPARKLE_SRC" ]] || { echo 'Sparkle.framework not found in .build/artifacts' >&2; exit 1; }
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE_SRC" "$APP/Contents/Frameworks/Sparkle.framework"

if [[ "$CONFIG" == release ]]; then
  scripts/check-universal.sh "$APP"
fi

# Sign inside out: Sparkle's helpers, the framework, then the app.
sign() { codesign --force $SIGN_FLAGS --sign "$IDENTITY" "$1"; }
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for item in XPCServices/Downloader.xpc XPCServices/Installer.xpc Updater.app Autoupdate Sparkle; do
  sign "$SPARKLE/Versions/Current/$item"
done
sign "$SPARKLE"
sign "$APP"
echo "built $APP ($CONFIG, $VERSION build $BUILD)"
