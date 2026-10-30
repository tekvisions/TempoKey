#!/usr/bin/env bash
#
# Builds TempoKey (Release, universal) and packages it into dist/TempoKey-<version>.dmg.
#
# Unsigned (local only):
#     ./scripts/package-dmg.sh
#
# Signed + notarized (for distribution — opens on any Mac):
#     export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
#     export NOTARY_PROFILE="TempoKeyNotary"      # created via `notarytool store-credentials`
#     ./scripts/package-dmg.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="TempoKey"
CONFIG="Release"
ENTITLEMENTS="TempoKeyApp/TempoKey.entitlements"
DIST="dist"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate >/dev/null

DERIVED="$(mktemp -d)"
trap 'rm -rf "$DERIVED"' EXIT

echo "▶ Building $SCHEME ($CONFIG, universal)…"
xcodebuild -project TempoKey.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" -destination 'platform=macOS' \
  ONLY_ACTIVE_ARCH=NO clean build >/dev/null
APP="$DERIVED/Build/Products/$CONFIG/TempoKey.app"
[ -d "$APP" ] || { echo "✗ build product not found at $APP"; exit 1; }
lipo "$APP/Contents/MacOS/TempoKey" -verify_arch arm64 x86_64

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
mkdir -p "$DIST"
DMG="$DIST/TempoKey-$VERSION.dmg"
rm -f "$DMG"

if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "▶ Signing app with Developer ID (strips get-task-allow, enables hardened runtime)…"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$DEVELOPER_ID" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"

  if [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "▶ Notarizing app…"
    ZIP="$DERIVED/TempoKey.zip"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"          # staple so it works offline after copy
  else
    echo "⚠ NOTARY_PROFILE not set — app is signed but NOT notarized."
  fi
else
  echo "⚠ DEVELOPER_ID not set — building an UNSIGNED (ad-hoc) DMG. It runs locally but"
  echo "  Gatekeeper will block a downloaded copy on other Macs. See docs/RELEASING-GITHUB.md."
fi

echo "▶ Building DMG…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "TempoKey $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --sign "$DEVELOPER_ID" "$DMG"
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "▶ Notarizing DMG…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    echo "▶ Gatekeeper check:"
    spctl -a -vvv -t open --context context:primary-signature "$DMG"
  fi
fi

echo "✅ $DMG  ($(du -h "$DMG" | awk '{print $1}'), v$VERSION)"
