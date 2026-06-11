# Releasing TempoKey as a downloadable DMG

This documents how to package TempoKey so it opens cleanly on **other** people's Macs.

## TL;DR readiness status

| Item | Status |
|---|---|
| Universal binary (arm64 + x86_64) | ✅ yes |
| Hardened runtime enabled | ✅ yes |
| App Sandbox + user-selected file access (Release) | ✅ yes |
| Bundle id / version (`com.tempokey.app`, 0.1.0) | ✅ yes |
| Runs across formats/lengths without crashing | ✅ verified |
| **Code signing for distribution** | ❌ **ad-hoc only — must fix** |
| **Notarization** | ❌ **required for download** |
| App icon | ✅ yes (circle-of-fifths wheel + tempo pulse) |
| Minimum macOS | 14.0 (won't run on 13 or earlier) |

**The blocker:** the local build is *ad-hoc* signed (`Signature=adhoc`, `spctl` → `rejected`).
A DMG of that build, once downloaded (and therefore quarantined), will be blocked by
Gatekeeper — users get *"TempoKey is damaged and can't be opened"* or *"cannot be opened
because Apple cannot check it for malicious software."* To distribute by download you must
**sign with a Developer ID Application certificate and notarize**.

## Prerequisites (one-time)

1. **Apple Developer Program** membership ($99/yr) — required for a Developer ID certificate
   and notarization.
2. A **Developer ID Application** certificate in your login keychain
   (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ▸ Developer ID Application).
3. A **notarytool credential profile** (App Store Connect API key or an app-specific password):
   ```bash
   xcrun notarytool store-credentials TempoKeyNotary \
     --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-password"
   ```

Set your Team ID in the project so signed builds use it:
`project.yml` ▸ target settings ▸ `DEVELOPMENT_TEAM: YOURTEAMID`, then `xcodegen generate`.

## Option A — Xcode Organizer (simplest)

1. Xcode ▸ Product ▸ **Archive** (scheme TempoKey, Release).
2. In the Organizer, **Distribute App ▸ Direct Distribution** (Developer ID).
   Xcode signs with Developer ID, strips `get-task-allow`, and submits for notarization.
3. When notarization succeeds, **Export** the `.app` (it's stapled).
4. Make the DMG (see "Build the DMG" below), then notarize + staple the DMG too.

## Option B — Command line

```bash
# 1. Build a Release .app
xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -configuration Release \
  -derivedDataPath build clean build
APP="build/Build/Products/Release/TempoKey.app"

# 2. Re-sign with Developer ID + hardened runtime + the sandbox entitlements
#    (get-task-allow must NOT be present in the distribution build)
codesign --force --deep --options runtime --timestamp \
  --entitlements TempoKeyApp/TempoKey.entitlements \
  --sign "Developer ID Application: Your Name (YOURTEAMID)" "$APP"

# 3. Verify the signature is Developer ID (not adhoc) and hardened
codesign -dvvv "$APP" 2>&1 | grep -E "Authority|flags"

# 4. Build the DMG (see below), then notarize the DMG
xcrun notarytool submit TempoKey.dmg --keychain-profile TempoKeyNotary --wait

# 5. Staple the ticket so it works offline
xcrun stapler staple TempoKey.dmg

# 6. Final gate check — should say "accepted, source=Notarized Developer ID"
spctl -a -vvv -t open --context context:primary-signature TempoKey.dmg
```

## Build the DMG

Simple (ad-hoc layout):
```bash
APP="build/Build/Products/Release/TempoKey.app"
rm -rf dmgroot && mkdir dmgroot
cp -R "$APP" dmgroot/
ln -s /Applications dmgroot/Applications          # drag-to-install affordance
hdiutil create -volname "TempoKey" -srcfolder dmgroot -ov -format UDZO TempoKey.dmg
```

Nicer (background image, icon layout): install `create-dmg`
(`brew install create-dmg`) and run:
```bash
create-dmg --volname "TempoKey" --app-drop-link 450 180 \
  --window-size 640 360 TempoKey.dmg "$APP"
```

After creating the DMG, **notarize and staple the DMG** (steps 4–5 above). Notarizing the
`.app` alone is not enough — staple the artifact you actually distribute.

## No Developer ID account? (not recommended for public download)

You can ship the ad-hoc build, but recipients must defeat Gatekeeper manually:
- Right-click the app ▸ **Open** ▸ Open (per machine, per app), or
- `xattr -dr com.apple.quarantine /Applications/TempoKey.app` after copying.

This is fragile (ad-hoc + quarantine often shows "damaged"), unfriendly, and unsuitable for a
general audience. Proper Developer ID + notarization is the only smooth download experience.

## Known limitations to mention in release notes

- Requires **macOS 14+**.
- Tempo is reliable on clearly rhythmic music; weakly-rhythmic/ambient material can yield an
  octave-off or arbitrary BPM. Very short clips (< ~3 s) report `0.00 BPM`.
- Key estimates are approximate, especially on percussive/atonal material (confidence shown).
