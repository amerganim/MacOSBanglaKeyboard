#!/bin/bash
# Removes Amader Bangla Keyboard (per-user and system-wide copies).
#   curl -fsSL https://raw.githubusercontent.com/amerganim/MacOSBanglaKeyboard/main/scripts/uninstall.sh | bash
set -uo pipefail
APP_NAME="AmaderBanglaKeyboard.app"
EXE="AmaderBanglaKeyboard"
for dir in "$HOME/Library/Input Methods" "/Library/Input Methods"; do
  app="$dir/$APP_NAME"
  [ -d "$app" ] || continue
  "$app/Contents/MacOS/$EXE" --disable 2>/dev/null || true
  pkill -x "$EXE" 2>/dev/null || true
  if [ -w "$dir" ]; then rm -rf "$app"; else sudo rm -rf "$app"; fi
  echo "Removed $app"
done
echo "Your learned words are kept in ~/Library/Application Support/AmaderBanglaKeyboard (delete it if you like)."
echo "Log out and back in to clear it from the input menu completely."
