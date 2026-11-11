#!/bin/sh
# Adds OpenReader to the "Open With" menu and the app launcher for the current
# user (no root needed). Run it from the extracted bundle folder:
#   ./install-desktop-entry.sh            install
#   ./install-desktop-entry.sh --remove   uninstall
# It does not change any default application.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"

if [ "${1:-}" = "--remove" ]; then
  rm -f "$apps/openreader.desktop" "$icons/openreader.png"
else
  mkdir -p "$apps" "$icons"
  cp "$here/openreader.png" "$icons/openreader.png"
  sed "s|@EXEC@|$here/openreader|" "$here/openreader.desktop" > "$apps/openreader.desktop"
fi

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" || true
echo "Done."
