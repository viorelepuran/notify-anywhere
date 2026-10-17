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
DEV_ID=$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')

if [[ -n "$DEV_ID" ]]; then
  export SIGN_IDENTITY="$DEV_ID"
else
  echo "⚠️  No 'Developer ID Application' certificate found. The DMG will be signed for development only"
  echo "    and customers will see a Gatekeeper warning. See the header of this script."
fi

./build.sh
APP="build/$NAME.app"

# Secure timestamp is required for notarization
if [[ -n "$DEV_ID" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

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

echo "Release ready: $DMG"
