#!/bin/sh
# Installs the latest OpenReader release on Linux (x86_64) or macOS.
#   curl -fsSL https://raw.githubusercontent.com/macdipu/OpenReader/main/install.sh | sh
# Uses .deb (apt) or .rpm (dnf/zypper) when available, otherwise the AppImage,
# otherwise the tarball (installed per user, no root).
# On macOS it installs OpenReader.app into /Applications (or ~/Applications if that is not writable).
set -eu

repo="macdipu/OpenReader"

os=$(uname -s)
case "$os" in
  Linux)
    case "$(uname -m)" in
      x86_64|amd64) ;;
      *) echo "Only x86_64 Linux builds are published." >&2; exit 1 ;;
    esac ;;
  Darwin) ;;
  *) echo "Unsupported OS. Downloads: https://github.com/$repo/releases/latest" >&2; exit 1 ;;
esac
command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 1; }

urls=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*"' | sed 's/.*: *"//; s/"$//')

pick() { printf '%s\n' "$urls" | grep -E "$1" | head -n 1 || true; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sudo_cmd=""
[ "$(id -u)" -eq 0 ] || sudo_cmd="sudo"

fetch() { echo "Downloading ${1##*/}"; curl -fSL -o "$tmp/${1##*/}" "$1"; }

if [ "$os" = "Darwin" ]; then
  # Prefer the .dmg; v1.0.10 only has a .zip. Standard location is /Applications (writable by
  # admin users); fall back to ~/Applications otherwise.
  app_dir="/Applications"
  if [ ! -w "$app_dir" ]; then
    app_dir="$HOME/Applications"
    mkdir -p "$app_dir"
  fi
  if url=$(pick 'macos\.dmg$') && [ -n "$url" ]; then
    fetch "$url"
    mnt="$tmp/mnt"
    mkdir -p "$mnt"
    hdiutil attach -nobrowse -quiet -mountpoint "$mnt" "$tmp/${url##*/}"
    rm -rf "$app_dir/OpenReader.app"
    cp -R "$mnt/OpenReader.app" "$app_dir/"
    hdiutil detach -quiet "$mnt" || true
  elif url=$(pick 'macos.*\.zip$') && [ -n "$url" ]; then
    fetch "$url"
    rm -rf "$app_dir/OpenReader.app"
    ditto -x -k "$tmp/${url##*/}" "$app_dir"
  else
    echo "No macOS download found in the latest release." >&2
    exit 1
  fi
  # Unsigned build: clear the download quarantine so first launch is not blocked.
  xattr -dr com.apple.quarantine "$app_dir/OpenReader.app" 2>/dev/null || true
  echo "Installed to $app_dir/OpenReader.app"
elif command -v apt-get >/dev/null 2>&1 && url=$(pick '_amd64\.deb$') && [ -n "$url" ]; then
  fetch "$url"; $sudo_cmd apt-get install -y "$tmp/${url##*/}"
elif command -v dnf >/dev/null 2>&1 && url=$(pick '\.x86_64\.rpm$') && [ -n "$url" ]; then
  fetch "$url"; $sudo_cmd dnf install -y "$tmp/${url##*/}"
elif command -v zypper >/dev/null 2>&1 && url=$(pick '\.x86_64\.rpm$') && [ -n "$url" ]; then
  fetch "$url"; $sudo_cmd zypper --non-interactive --no-gpg-checks install "$tmp/${url##*/}"
elif url=$(pick 'x86_64\.AppImage$') && [ -n "$url" ]; then
  mkdir -p "$HOME/.local/bin"
  fetch "$url"
  install -m 755 "$tmp/${url##*/}" "$HOME/.local/bin/OpenReader.AppImage"
  echo "Installed to ~/.local/bin/OpenReader.AppImage"
elif url=$(pick 'linux-x64.*\.tar\.gz$') && [ -n "$url" ]; then
  dest="$HOME/.local/share/openreader"
  fetch "$url"
  mkdir -p "$dest"
  tar -xzf "$tmp/${url##*/}" -C "$dest"
  "$dest/install-desktop-entry.sh"
  echo "Installed to $dest"
else
  echo "No Linux package found in the latest release." >&2
  exit 1
fi
echo "OpenReader installed."
