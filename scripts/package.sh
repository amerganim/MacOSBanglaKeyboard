#!/bin/bash
# Builds the release artifacts into dist/:
#   AmaderBanglaKeyboard.zip          the app (used by install.sh)
#   AmaderBanglaKeyboard-<ver>.pkg    double-click installer (installs for all users)
set -euo pipefail
VERSION="${1:?version}"
cd "$(dirname "$0")/.."
APP="build/AmaderBanglaKeyboard.app"
[ -d "$APP" ] || { echo "Build first: make"; exit 1; }
rm -rf dist && mkdir -p dist/pkgroot
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP" dist/AmaderBanglaKeyboard.zip
ditto --norsrc --noextattr --noqtn "$APP" "dist/pkgroot/AmaderBanglaKeyboard.app"
chmod +x pkg/scripts/postinstall
# Never let Installer "relocate" the bundle to some other copy it finds.
pkgbuild --analyze --root dist/pkgroot dist/component.plist >/dev/null
/usr/libexec/PlistBuddy -c "Delete :0:BundleIsRelocatable" dist/component.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" dist/component.plist
xattr -cr dist/pkgroot 2>/dev/null || true
COPYFILE_DISABLE=1 pkgbuild --root dist/pkgroot --component-plist dist/component.plist \
  --identifier io.github.amerganim.inputmethod.AmaderBanglaKeyboard.pkg \
  --version "$VERSION" \
  --install-location "/Library/Input Methods" \
  --scripts pkg/scripts \
  "dist/AmaderBanglaKeyboard-$VERSION.pkg"
rm -rf dist/pkgroot dist/component.plist
(cd dist && shasum -a 256 * > SHA256SUMS.txt)
ls -la dist
