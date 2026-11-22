# Releases

Versions are `X.Y`, bumped by 0.1 each release (0.9 is followed by 0.10 unless you ask for 1.0). User-visible changes go in `CHANGELOG.md` under `## Unreleased` as they land, written for users.

Run `just release` from a clean `main` that matches `origin/main` (or `just release 1.0` to pick the version; the first release has no tag to bump, so it needs one). It:

1. runs the tests, renames `## Unreleased` to `## X.Y`, sets `version:` in `docs/_config.yml` (the manual's front page shows it), and commits and pushes `Release X.Y`;
2. builds a universal bundle for Apple silicon and Intel, signs it with the Developer ID Application certificate (hardened runtime), notarizes and staples it with the `danky-notary` keychain profile, and zips it to `dist/scuttle.app.zip`;
3. signs the zip for Sparkle and writes `dist/appcast.xml`, with the `## X.Y` section of the changelog, rendered by GitHub, as the notes the update window shows, and `dist/scuttle.rb` from `scripts/scuttle.rb.template`;
4. tags `vX.Y`, publishes a GitHub release on [ahacop/scuttle](https://github.com/ahacop/scuttle) with the changelog section as notes and the zip, appcast and cask attached, and pushes `Casks/scuttle.rb` to [ahacop/homebrew-tap](https://github.com/ahacop/homebrew-tap) through a temporary clone.

Running it again without adding commits reuses the `Release X.Y` commit and retries a failed release or tap update; a published version is never replaced.

`just package X.Y` does steps 2 and 3 only, without committing or publishing. Override `NOTARYTOOL_PROFILE` or `DEVELOPER_ID_APPLICATION` (a name or SHA-1 hash) when needed; by default packaging picks the first Developer ID Application certificate by hash, because `security find-identity` mangles the "ä" in "Tehanu UG (haftungsbeschränkt)". The build number is the commit count plus 100.

## One-time setup on a new Mac

- **Developer ID Application certificate** for team `85A247G9GJ`, in the login keychain. Only the Account Holder can create one: make a CSR in Keychain Access, sign in to developer.apple.com as the Account Holder, create the certificate from it, and double-click the `.cer` (choose **login**). Check with `security find-identity -v -p codesigning | grep "Developer ID"`.
- **Notary profile**, from the App Store Connect API key (`~/.appstoreconnect/AuthKey_*.p8`, IDs in naswildcard's `fastlane/.env`):

  ```sh
  xcrun notarytool store-credentials danky-notary --key <AuthKey.p8> --key-id <key id> --issuer <issuer id>
  ```

- **Sparkle signing key**, imported from the backup (below).
- `gh` signed in with push access to both repos.

## Builds

Release bundles use `swift build -c release --jobs 4 --arch arm64 --arch x86_64`, with the same flags for `--show-bin-path` rather than assuming a SwiftPM output directory. `scripts/bundle.sh --debug` stays native for local development. Both architectures support macOS 15 or later; Intel Macs stop at macOS 26.

`scripts/check-universal.sh path/to/scuttle.app` checks both slices in the main executable, Sparkle framework, Autoupdate, Updater, Downloader and Installer. Bundling runs it before signing; packaging repeats it before notarization and on the unpacked shipping zip before generating the architecture-unrestricted cask. Add any new bundled executables to this check. The appcast still derives its architecture requirement from the executable, so an arm64-only build cannot offer an incompatible update to Intel Macs.

`python3 -m unittest discover -s scripts/tests -v` runs isolated packaging regressions (also part of `just test` and CI). These mock build, signing and notarization; a real release still needs Developer ID verification, notarization, Gatekeeper assessment and a Sparkle update smoke test on each architecture.

## Updates

scuttle updates itself with [Sparkle](https://sparkle-project.org) (SwiftPM package, `Sparkle.framework` in `Contents/Frameworks`, signed inside out by `scripts/bundle.sh`). The feed, `SUFeedURL` in `Resources/Info.plist`, is https://github.com/ahacop/scuttle/releases/latest/download/appcast.xml: the `appcast.xml` asset of the latest release, so publishing a release is what ships the update. `scripts/appcast.py` writes it from the built app and the zip.

Only builds with `VERSION` set, which means release packaging, keep `SUFeedURL`. `just run`, `just install` and other local bundles drop it, so they show no Check for Updates and never replace themselves with a release.

Updates are signed with an EdDSA key whose private half lives in the login keychain under the account `com.ahacop.scuttle`; `sign_update --account com.ahacop.scuttle` uses it during packaging. The public key, `SUPublicEDKey`, is `2Bp5bnBWzDDjzhRsmVyyb+wXHSuZbWPkZuVXRQoPnXk=`. Losing the private key means installed copies can no longer update, so keep a backup somewhere safe, such as a password manager:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x scuttle-sparkle-key --account com.ahacop.scuttle
```

Import it on another Mac with `generate_keys -f scuttle-sparkle-key --account com.ahacop.scuttle`.
