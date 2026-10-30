#!/usr/bin/env bash
# Checks linux/packaging/package-linux.sh without a Flutter build: it makes a stand-in bundle (an
# executable that echoes its arguments, plus lib/ and data/), builds each package from it inside a
# Debian and a Fedora container, installs it, checks the files, the desktop entry and the AppStream
# file, removes it, and runs the AppImage.
#
#   tool/test_linux_packages.sh            run both containers (needs Docker)
#   tool/test_linux_packages.sh debian     what runs inside the Debian container
#   tool/test_linux_packages.sh fedora     what runs inside the Fedora container
#
# Packages land in build/packages-test/. It proves the packaging works, not that the real Flutter
# app starts: install the artifact from a release on a real machine for that.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)

make_bundle() {
  bundle=/tmp/bundle
  mkdir -p "$bundle/lib" "$bundle/data/flutter_assets"
  printf '#!/bin/sh\necho "openreader started with: $*"\n' >"$bundle/openreader"
  chmod +x "$bundle/openreader"
  touch "$bundle/lib/libflutter_linux_gtk.so" "$bundle/data/flutter_assets/AssetManifest.bin"
  # What CI's tarball step adds, which the packages must leave out:
  touch "$bundle/install-desktop-entry.sh" "$bundle/openreader.desktop" "$bundle/openreader.png"
}

in_debian() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null
  apt-get install -y -qq dpkg-dev desktop-file-utils appstream wget file ca-certificates >/dev/null
  make_bundle
  echo "=== .deb ==="
  bash /src/linux/packaging/package-linux.sh deb "$bundle" 1.0.11 13 /out
  deb=/out/openreader_1.0.11-13_amd64.deb
  dpkg-deb -I "$deb" | sed -n 1,16p
  dpkg-deb -c "$deb" | awk '{print $1, $6, $7, $8}'
  # The slim image lacks GTK and friends, so install while ignoring the declared dependencies.
  dpkg -i --force-depends "$deb" 2>&1 | tail -3
  openreader /tmp/some.pdf
  test -x /usr/bin/openreader
  test ! -e /opt/openreader/install-desktop-entry.sh
  desktop-file-validate /usr/share/applications/openreader.desktop
  grep -q '^Exec=openreader %F$' /usr/share/applications/openreader.desktop
  appstreamcli validate --no-net /usr/share/metainfo/com.chowdhuryelab.openreader.metainfo.xml || true
  dpkg -r openreader | tail -1
  test ! -e /opt/openreader && test ! -e /usr/bin/openreader
  echo "deb: install, run, validate, remove: ok"

  echo "=== AppImage ==="
  wget -q -O /tmp/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x /tmp/appimagetool
  APPIMAGETOOL="/tmp/appimagetool --appimage-extract-and-run" \
    bash /src/linux/packaging/package-linux.sh appimage "$bundle" 1.0.11 13 /out
  img=/out/OpenReader-1.0.11-x86_64.AppImage
  file "$img" | cut -c1-110
  "$img" --appimage-extract-and-run /tmp/some.pdf
  echo "AppImage: build and run: ok"
}

in_fedora() {
  dnf install -y -q rpm-build desktop-file-utils >/dev/null
  make_bundle
  echo "=== .rpm ==="
  bash /src/linux/packaging/package-linux.sh rpm "$bundle" 1.0.11 13 /out
  rpm=$(ls /out/openreader-1.0.11-13*.rpm)
  rpm -qpi "$rpm" | sed -n 1,12p
  rpm -qpl "$rpm"
  rpm -qpR "$rpm"
  # --nodeps: the slim image has no GTK; the declared requirements are shown above.
  rpm -ivh --nodeps "$rpm" 2>&1 | tail -2
  openreader /tmp/some.pdf
  test -x /usr/bin/openreader
  test ! -e /opt/openreader/install-desktop-entry.sh
  desktop-file-validate /usr/share/applications/openreader.desktop
  rpm -e openreader
  test ! -e /opt/openreader && test ! -e /usr/bin/openreader
  echo "rpm: install, run, validate, remove: ok"
}

case "${1:-}" in
  debian) in_debian ;;
  fedora) in_fedora ;;
  *)
    out="$repo/build/packages-test"
    mkdir -p "$out"
    for image in debian:bookworm fedora:latest; do
      case "$image" in debian*) mode=debian ;; *) mode=fedora ;; esac
      docker run --rm -v "$repo:/src:ro" -v "$out:/out" "$image" bash /src/tool/test_linux_packages.sh "$mode"
    done
    ls -l "$out"
    ;;
esac
