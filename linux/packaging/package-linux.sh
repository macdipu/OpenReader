#!/usr/bin/env bash
# Builds a Linux package from a Flutter release bundle.
#
#   package-linux.sh <deb|rpm|appimage> <bundle-dir> <version> <build> <out-dir>
#
#   bundle-dir  build/linux/x64/release/bundle
#   version     1.0.11            (the part of pubspec's "1.0.11+13" before the +)
#   build       13                (the part after the +)
#
# deb and rpm install the app under /opt/openreader with a /usr/bin/openreader link, a desktop
# entry (so it is in the launcher and in "Open with" for the document types it reads), an icon and
# AppStream metadata (so software centres can show it). The AppImage is one file that runs
# anywhere with GTK 3 and libsecret, no install needed.
set -euo pipefail

format=${1:?format: deb | rpm | appimage}
bundle=${2:?path to the Flutter bundle}
version=${3:?version, e.g. 1.0.11}
build=${4:?build number, e.g. 13}
out=${5:?output directory}

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
icon="$repo/assets/icon/icon.png"
homepage="https://macdipu.github.io/OpenReader/"
maintainer="macdipu <macdipu@users.noreply.github.com>"
summary="Reader for PDF, Word, Excel, PowerPoint, text and CSV files"

[ -x "$bundle/openreader" ] || { echo "no executable at $bundle/openreader" >&2; exit 1; }
mkdir -p "$out"
out=$(cd "$out" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

# The bundle plus the extras the tarball adds; packages carry their own copies in the right places.
copy_bundle() {
  cp -a "$bundle"/. "$1"
  rm -f "$1/install-desktop-entry.sh" "$1/openreader.desktop" "$1/openreader.png"
  chmod 755 "$1/openreader"
}

desktop_entry() { sed 's|@EXEC@|openreader|' "$here/openreader.desktop"; }

metainfo() {
  sed -e "s|@VERSION@|$version|g" -e "s|@DATE@|$(date -u +%Y-%m-%d)|g" \
    "$here/com.chowdhuryelab.openreader.metainfo.xml"
}

# Filesystem layout shared by deb and rpm.
install_tree() {
  local root=$1
  install -d "$root/opt/openreader" "$root/usr/bin" "$root/usr/share/applications" \
    "$root/usr/share/icons/hicolor/512x512/apps" "$root/usr/share/metainfo"
  copy_bundle "$root/opt/openreader"
  ln -s /opt/openreader/openreader "$root/usr/bin/openreader"
  desktop_entry >"$root/usr/share/applications/openreader.desktop"
  install -m 644 "$icon" "$root/usr/share/icons/hicolor/512x512/apps/openreader.png"
  metainfo >"$root/usr/share/metainfo/com.chowdhuryelab.openreader.metainfo.xml"
  find "$root" -type d -exec chmod 755 {} +
  chmod 644 "$root/usr/share/applications/openreader.desktop" \
    "$root/usr/share/metainfo/com.chowdhuryelab.openreader.metainfo.xml"
}

refresh_caches='
if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database -q /usr/share/applications || true; fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true; fi
'

build_deb() {
  local root="$stage/deb"
  install_tree "$root"
  mkdir -p "$root/DEBIAN"
  cat >"$root/DEBIAN/control" <<EOF
Package: openreader
Version: $version-$build
Section: text
Priority: optional
Architecture: amd64
Depends: libgtk-3-0 | libgtk-3-0t64, libsecret-1-0, libjsoncpp25 | libjsoncpp26 | libjsoncpp24 | libjsoncpp1, liblzma5, libc6
Installed-Size: $(du -sk "$root" | cut -f1)
Maintainer: $maintainer
Homepage: $homepage
Description: $summary
 OpenReader opens PDF, Word, Excel, PowerPoint, Markdown, text and CSV
 files in one fast app. It works offline: no account, no uploads, no
 tracking. Open documents in tabs or side by side, and add it to your file
 manager's "Open with" menu.
EOF
  printf '#!/bin/sh\nset -e\n%s\n' "$refresh_caches" >"$root/DEBIAN/postinst"
  printf '#!/bin/sh\nset -e\n%s\n' "$refresh_caches" >"$root/DEBIAN/postrm"
  chmod 755 "$root/DEBIAN/postinst" "$root/DEBIAN/postrm"
  dpkg-deb --root-owner-group --build "$root" "$out/openreader_${version}-${build}_amd64.deb" >/dev/null
  echo "$out/openreader_${version}-${build}_amd64.deb"
}

build_rpm() {
  local top="$stage/rpm"
  install -d "$top"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  install_tree "$top/SOURCES/root"
  cat >"$top/SPECS/openreader.spec" <<EOF
Name:           openreader
Version:        $version
Release:        $build
Summary:        $summary
License:        Unspecified
URL:            $homepage
BuildArch:      x86_64
# The bundle ships its own Flutter engine and plugin libraries; rpm must not scan them for
# requirements it cannot satisfy. The system libraries it really needs are listed by hand.
AutoReqProv:    no
Requires:       gtk3, libsecret, jsoncpp, xz-libs
%global debug_package %{nil}
%global __os_install_post %{nil}

%description
OpenReader opens PDF, Word, Excel, PowerPoint, Markdown, text and CSV files in one fast app.
It works offline: no account, no uploads, no tracking. Open documents in tabs or side by side,
and add it to your file manager's "Open with" menu.

%install
mkdir -p %{buildroot}
cp -a %{_sourcedir}/root/. %{buildroot}/

%post
$refresh_caches
%postun
$refresh_caches

%files
/opt/openreader
/usr/bin/openreader
/usr/share/applications/openreader.desktop
/usr/share/icons/hicolor/512x512/apps/openreader.png
/usr/share/metainfo/com.chowdhuryelab.openreader.metainfo.xml

%changelog
* $(LC_ALL=C date '+%a %b %d %Y') OpenReader <noreply@users.noreply.github.com> - $version-$build
- Release $version (build $build)
EOF
  rpmbuild -bb --quiet --define "_topdir $top" "$top/SPECS/openreader.spec"
  cp "$top"/RPMS/x86_64/openreader-*.rpm "$out/"
  ls "$out"/openreader-"$version"-"$build"*.rpm
}

build_appimage() {
  local appdir="$stage/OpenReader.AppDir"
  install -d "$appdir/usr/lib/openreader"
  copy_bundle "$appdir/usr/lib/openreader"
  cat >"$appdir/AppRun" <<'EOF'
#!/bin/sh
# Resolve the AppDir through any symlinks, then start the Flutter bundle (which finds its lib/ and
# data/ next to the executable).
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/lib/openreader/openreader" "$@"
EOF
  chmod 755 "$appdir/AppRun"
  desktop_entry >"$appdir/openreader.desktop"
  install -m 644 "$icon" "$appdir/openreader.png"
  ln -s openreader.png "$appdir/.DirIcon"
  local target="$out/OpenReader-${version}-x86_64.AppImage"
  # APPIMAGETOOL may carry options, e.g. "appimagetool-x86_64.AppImage --appimage-extract-and-run"
  # on a machine without FUSE (CI runners, containers).
  # shellcheck disable=SC2086
  ARCH=x86_64 ${APPIMAGETOOL:-appimagetool} "$appdir" "$target" >/dev/null
  chmod 755 "$target"
  echo "$target"
}

case "$format" in
  deb) build_deb ;;
  rpm) build_rpm ;;
  appimage) build_appimage ;;
  *) echo "unknown format: $format (deb | rpm | appimage)" >&2; exit 1 ;;
esac
