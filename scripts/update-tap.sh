#!/bin/bash
# After a release is published, point the Homebrew cask at it:
#   ./scripts/update-tap.sh 1.0.2
set -euo pipefail
VERSION="${1:?version, e.g. 1.0.2}"
URL="https://github.com/amerganim/MacOSBanglaKeyboard/releases/download/v$VERSION/AmaderBanglaKeyboard.zip"
SHA=$(curl -fsSL "$URL" | shasum -a 256 | cut -d' ' -f1)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
gh repo clone amerganim/homebrew-tap "$TMP/tap" -- -q
CASK="$TMP/tap/Casks/amader-bangla-keyboard.rb"
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
git -C "$TMP/tap" commit -qam "amader-bangla-keyboard $VERSION"
git -C "$TMP/tap" push -q
echo "Cask updated to $VERSION ($SHA)"
