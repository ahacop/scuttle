#!/usr/bin/env bash
# Builds, signs with Developer ID, notarizes and staples scuttle.app, zips it into dist/, and writes the Sparkle
# appcast and the Homebrew cask.
# Usage: scripts/package-release.sh 0.3
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?Usage: scripts/package-release.sh X.Y}"
version="${version#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+$ ]] || { echo 'Expected version X.Y' >&2; exit 1; }
profile="${NOTARYTOOL_PROFILE:-danky-notary}"
# The certificate's SHA-1 hash, not its name: find-identity mangles non-ASCII names, which codesign then fails to match.
identity="${DEVELOPER_ID_APPLICATION:-$(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) "Developer ID Application:.*/\1/p' | head -1)}"
[[ -n "$identity" ]] || { echo 'No Developer ID Application identity; set DEVELOPER_ID_APPLICATION' >&2; exit 1; }
build="$(( $(git rev-list --count HEAD) + 100 ))"

echo "==> Building and signing scuttle.app $version ($build) with $identity"
VERSION="$version" BUILD="$build" IDENTITY="$identity" SIGN_FLAGS="--options runtime --timestamp" scripts/bundle.sh
scripts/check-universal.sh build/scuttle.app
codesign --verify --strict --verbose=1 build/scuttle.app

mkdir -p dist
rm -f dist/scuttle.app.zip dist/signature.txt dist/appcast.xml dist/scuttle.rb
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "==> Notarizing with profile $profile"
ditto -c -k --sequesterRsrc --keepParent build/scuttle.app "$tmp/scuttle.zip"
xcrun notarytool submit "$tmp/scuttle.zip" --keychain-profile "$profile" --wait
xcrun stapler staple build/scuttle.app
spctl --assess --type execute --verbose=1 build/scuttle.app

ditto -c -k --sequesterRsrc --keepParent build/scuttle.app dist/scuttle.app.zip

# Check the actual shipping archive too, before generating an unrestricted Homebrew cask.
ditto -x -k dist/scuttle.app.zip "$tmp/unpacked"
scripts/check-universal.sh "$tmp/unpacked/scuttle.app"

echo "==> Signing the update and writing the appcast and the cask"
sign_update="$(find .build/artifacts -path '*/Sparkle/bin/sign_update' | head -1)"
"$sign_update" --account com.ahacop.scuttle -p dist/scuttle.app.zip > dist/signature.txt
# sign_update can print a Keychain error and still exit 0, for instance when its Keychain prompt can't be shown.
grep -Eqx '[A-Za-z0-9+/]{86}==' dist/signature.txt || {
  echo "Sparkle signing failed: $(cat dist/signature.txt)" >&2
  echo "Run $sign_update --account com.ahacop.scuttle dist/scuttle.app.zip in Terminal and choose Always Allow." >&2
  exit 1
}
python3 scripts/appcast.py "$version"
sed -e "s/@VERSION@/$version/" -e "s/@SHA256@/$(shasum -a 256 dist/scuttle.app.zip | cut -d' ' -f1)/" scripts/scuttle.rb.template > dist/scuttle.rb
echo "==> dist/scuttle.app.zip ($(du -h dist/scuttle.app.zip | cut -f1)), version $version build $build"
