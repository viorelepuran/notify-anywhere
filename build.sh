#!/bin/zsh
# Builds "Notify Anywhere.app" (universal) into ./build
set -euo pipefail
cd "$(dirname "$0")"

NAME="Notify Anywhere"
EXEC="NotifyAnywhere"
APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

# App icon (.icns) from the 1024px master
if [[ ! -f build/AppIcon.icns || Resources/AppIcon-1024.png -nt build/AppIcon.icns ]]; then
  ICONSET=build/AppIcon.iconset
  rm -rf $ICONSET && mkdir -p $ICONSET
  for s in 16 32 128 256 512; do
    sips -z $s $s Resources/AppIcon-1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) Resources/AppIcon-1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns $ICONSET -o build/AppIcon.icns
  rm -rf $ICONSET
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/LiftoffLogo.png "$APP/Contents/Resources/"

for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $ARCH-apple-macos14.0 -o build/$EXEC-$ARCH Sources/*.swift
done
lipo -create build/$EXEC-arm64 build/$EXEC-x86_64 -output "$APP/Contents/MacOS/$EXEC"
rm build/$EXEC-arm64 build/$EXEC-x86_64

# Signing: SIGN_IDENTITY env var wins (use your "Developer ID Application" cert for distribution),
# then an Apple Development cert (keeps the Accessibility grant across rebuilds), then ad-hoc.
IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')}
IDENTITY=${IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')}
codesign --force --options runtime --timestamp=none --sign "${IDENTITY:--}" "$APP"

echo "Built: $APP"
