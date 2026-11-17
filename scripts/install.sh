#!/bin/bash
# Installs Amader Bangla Keyboard for the current user (no admin password).
#
#   One-line install (downloads the latest release):
#     curl -fsSL https://raw.githubusercontent.com/amerganim/MacOSBanglaKeyboard/main/scripts/install.sh | bash
#
#   From a local build:  ./scripts/install.sh --from-build build/AmaderBanglaKeyboard.app
set -euo pipefail

REPO="amerganim/MacOSBanglaKeyboard"
APP_NAME="AmaderBanglaKeyboard.app"
EXE="AmaderBanglaKeyboard"
DEST_DIR="$HOME/Library/Input Methods"
DEST="$DEST_DIR/$APP_NAME"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "This installer is for macOS."

SRC=""
TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT

if [ "${1:-}" = "--from-build" ]; then
  SRC="${2:?path to .app required}"
  [ -d "$SRC" ] || die "Not found: $SRC"
else
  TMP="$(mktemp -d)"
  URL="https://github.com/$REPO/releases/latest/download/AmaderBanglaKeyboard.zip"
  say "Downloading the latest Amader Bangla Keyboard…"
  curl -fL --progress-bar "$URL" -o "$TMP/abk.zip" || die "Download failed: $URL"
  ditto -x -k "$TMP/abk.zip" "$TMP" || die "Could not unzip the download."
  SRC="$TMP/$APP_NAME"
  [ -d "$SRC" ] || die "The download did not contain $APP_NAME."
fi

# Stop a running copy so the new one is picked up.
pkill -x "$EXE" 2>/dev/null || true

say "Installing to $DEST"
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
ditto "$SRC" "$DEST"
# Downloaded without a paid Apple certificate: clear the quarantine flag so
# macOS lets the input method run.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

say "Registering and enabling the input source"
"$DEST/Contents/MacOS/$EXE" --enable || true

if plutil -p "$HOME/Library/Preferences/com.apple.HIToolbox.plist" 2>/dev/null | grep -q AmaderBanglaKeyboard; then
  # Upgrade: already in the user's input sources.
  echo
  echo "  ✅ Amader Bangla Keyboard is updated. Switch away and back to it (or log out/in) to load the new version."
  echo
  exit 0
fi

cat <<MSG

  ✅ Amader Bangla Keyboard is installed.

  One last step (macOS requires you to do this yourself, once):
    System Settings → Keyboard → Text Input → Input Sources → Edit…
    → click + → choose "Bangla" → "Amader Bangla Keyboard" → Add.
  (Opening System Settings for you now. If it is not in the list yet,
   log out and back in, then try again.)

  Then pick it from the input menu in the menu bar, or press the 🌐 Globe
  key / Control+Space to switch.  Type phonetically:
      amar sOnar bangla  →  আমার সোনার বাংলা
  Control+Shift+B switches between Bangla and English.

MSG
open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" 2>/dev/null || open -b com.apple.systempreferences || true
