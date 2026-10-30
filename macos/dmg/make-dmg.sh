#!/usr/bin/env bash
# Builds the macOS installer disk image: open it, drag OpenReader onto Applications.
#
#   macos/dmg/make-dmg.sh <path/to/OpenReader.app> <output.dmg> <version>
#
# Uses create-dmg (brew install create-dmg) for the styled window: a background with an arrow, the
# app on the left and an Applications shortcut on the right. If create-dmg is missing or fails (it
# scripts Finder, which a headless machine can refuse), it falls back to a plain disk image that
# still holds the app and an Applications shortcut, so drag-and-drop install always works.
set -euo pipefail

app=${1:?path to OpenReader.app}
out=${2:?output .dmg path}
version=${3:?version, e.g. 1.0.11}

here=$(cd "$(dirname "$0")" && pwd)
name=$(basename "$app")
[ -d "$app" ] || { echo "no app bundle at $app" >&2; exit 1; }

mkdir -p "$(dirname "$out")"
rm -f "$out"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
# ditto keeps the bundle's symlinks, permissions and extended attributes (a plain cp -R can break
# the embedded frameworks).
ditto "$app" "$stage/$name"

styled() {
  # Positions match tool/generate_dmg_background.ps1 (the arrow sits between them).
  create-dmg \
    --volname "OpenReader $version" \
    --background "$here/background.png" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 120 \
    --icon "$name" 180 190 \
    --hide-extension "$name" \
    --app-drop-link 480 190 \
    --no-internet-enable \
    "$out" "$stage"
}

plain() {
  rm -f "$out"
  ln -s /Applications "$stage/Applications"
  hdiutil create -volname "OpenReader $version" -srcfolder "$stage" -ov -format UDZO "$out"
}

if command -v create-dmg >/dev/null 2>&1 && styled; then
  echo "Built styled DMG: $out"
else
  echo "create-dmg unavailable or failed; building a plain DMG with an Applications shortcut" >&2
  plain
  echo "Built plain DMG: $out"
fi

# A disk image that does not verify is worse than none: stop the release if this one is damaged.
hdiutil verify "$out"
