#!/bin/zsh
# Downloads the pinned Sparkle release (framework + signing tools) into ./Vendor/Sparkle.
# Called by build.sh; safe to run repeatedly.
set -euo pipefail
cd "$(dirname "$0")/.."

SPARKLE_VERSION=2.10.0
SPARKLE_SHA256=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
DEST=Vendor/Sparkle

[[ -f $DEST/.version && "$(cat $DEST/.version)" == "$SPARKLE_VERSION" ]] && exit 0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Sparkle $SPARKLE_VERSION…"
curl -fsSL -o "$TMP/sparkle.tar.xz" \
  "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
echo "$SPARKLE_SHA256  $TMP/sparkle.tar.xz" | shasum -a 256 -c - >/dev/null

rm -rf $DEST && mkdir -p $DEST
tar -xJf "$TMP/sparkle.tar.xz" -C $DEST
echo $SPARKLE_VERSION > $DEST/.version
