#!/bin/zsh
# Builds, signs, (optionally) notarizes and packages Notify Anywhere into a distributable DMG.
#
# For a build customers can open without Gatekeeper warnings you need:
#   1. A "Developer ID Application" certificate (Xcode → Settings → Accounts → Manage Certificates).
#   2. A notarytool keychain profile, created once with:
#        xcrun notarytool store-credentials NotifyAnywhere --apple-id <you@example.com> --team-id <TEAMID>
#   Then run:  NOTARY_PROFILE=NotifyAnywhere ./release.sh
set -euo pipefail
cd "$(dirname "$0")"

NAME="Notify Anywhere"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" Info.plist)
DEV_ID=$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')

# Sparkle compares CFBundleVersion, so a notarized release must bump it or existing users won't see the update.
if [[ -n "${NOTARY_PROFILE:-}" && -n "$DEV_ID" && -f appcast.xml ]] \
   && grep -q "<sparkle:version>$BUILD</sparkle:version>" appcast.xml; then
  echo "❌ CFBundleVersion $BUILD is already in appcast.xml. Bump it in Info.plist before releasing."
  exit 1
fi

if [[ -n "$DEV_ID" ]]; then
  export SIGN_IDENTITY="$DEV_ID"
  export CODESIGN_TIMESTAMP=--timestamp   # secure timestamp is required for notarization
else
  echo "⚠️  No 'Developer ID Application' certificate found. The DMG will be signed for development only"
  echo "    and customers will see a Gatekeeper warning. See the header of this script."
fi

./build.sh
APP="build/$NAME.app"

codesign --verify --deep --strict --verbose=2 "$APP"

# Disk image with drag-to-Applications layout
STAGE=build/dmg
DMG="build/NotifyAnywhere-$VERSION.dmg"
rm -rf $STAGE "$DMG" && mkdir -p $STAGE
cp -R "$APP" $STAGE/
ln -s /Applications $STAGE/Applications
hdiutil create -volname "$NAME $VERSION" -srcfolder $STAGE -ov -format UDZO "$DMG" >/dev/null
rm -rf $STAGE
[[ -n "$DEV_ID" ]] && codesign --sign "$DEV_ID" --timestamp "$DMG"

if [[ -n "${NOTARY_PROFILE:-}" && -n "$DEV_ID" ]]; then
  echo "Submitting to Apple notary service…"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature -v "$DMG"
fi

# Sparkle: EdDSA-sign the DMG and add it to appcast.xml. Only notarized builds go in the feed.
# The private key lives in the login keychain (created with Vendor/Sparkle/bin/generate_keys --account $SPARKLE_ACCOUNT).
# Optional release notes (Markdown or HTML): RELEASE_NOTES=path/to/notes.md
SPARKLE_ACCOUNT=ro.liftoffmedia.NotifyAnywhere
if [[ -n "${NOTARY_PROFILE:-}" && -n "$DEV_ID" ]]; then
  UPDATES=build/updates
  rm -rf $UPDATES && mkdir -p $UPDATES
  cp "$DMG" $UPDATES/
  [[ -f appcast.xml ]] && cp appcast.xml $UPDATES/
  [[ -n "${RELEASE_NOTES:-}" ]] && cp "$RELEASE_NOTES" "$UPDATES/NotifyAnywhere-$VERSION.${RELEASE_NOTES##*.}"
  Vendor/Sparkle/bin/generate_appcast "$UPDATES" \
    --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix "https://github.com/viorelepuran/notify-anywhere/releases/download/v$VERSION/" \
    --link "https://github.com/viorelepuran/notify-anywhere" \
    --embed-release-notes \
    --maximum-deltas 0
  cp $UPDATES/appcast.xml appcast.xml
  echo "Updated appcast.xml. Upload $DMG to the v$VERSION GitHub release first, then commit and push appcast.xml."
else
  echo "⚠️  Not notarized, so appcast.xml was left unchanged."
fi

echo "Release ready: $DMG"
