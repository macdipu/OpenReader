# TODO

Only what is still open. Finished items are removed; `git log` has the history.

## Needs a push before CI can build

- [ ] **Push the `universal_document_viewer` branch `desktop-scroll`** (PDF desktop scrollbar, touchpad scroll no
      longer zooms), then re-pin it in `pubspec.yaml` / `pubspec.lock`. OpenReader's `PdfView(showScrollbar: ...)`
      call does not exist in the currently pinned commit, so clean and CI builds fail until this is done.
      Local builds use `pubspec_overrides.yaml` (git-excluded) pointing at `../universal_document_viewer`.
- [ ] **Windows CI build fails.** Needs the failing step's log (`gh auth login`, or paste the error). The same
      `flutter build windows --release` passes locally once Visual Studio's ATL component is installed.

## Landing page

The device lineup (`docs/assets/devices/`) uses real captures: Windows desktop and Android phone, tablet and foldable (emulator size overrides). The **macOS laptop frame shows the Windows build** with its title bar cropped, and the page says so.

- [ ] Capture the real macOS app (light, `Exploring the World.docx`, about 1280x800) and replace `assets/devices/macos-laptop.png` (`tool/make_device_assets.ps1` resizes it), then drop the footnote in `index.html`.
- [ ] Capture Linux and add it to the downloads section if wanted.
- [ ] Link each platform button straight to its release asset instead of `releases/latest`, once file names are stable.
- [ ] Add a `LICENSE` file: the site and README say open source, but the repo has none.
- [ ] `docs/` is the published site, so this file and `docs/ui-audit/` are served publicly. Move them out if that is not wanted.

## Needs a real device or machine (built, not run)

- [ ] **macOS "Open With" and default app.** `AppDelegate.swift`: Finder open events, and
      `setDefaultForExtensions` (`NSWorkspace.setDefaultApplication`, macOS 12+). Check the confirmation prompt, that a
      declined type is reported, and that Finder's Open With reflects the change.
- [ ] **Linux "Open With" and default app.** `install-desktop-entry.sh`, then `xdg-mime default` per MIME type.
      Test on GNOME and KDE.
- [ ] **Android default app.** `MainActivity.kt` opens the system default-apps screen. Check Android 10 to 15, then
      that choosing OpenReader and tapping Always works for a PDF. Also check a file opened from another app lands
      in History.
- [ ] **Touchpad scroll no longer zooms** (PDF). Verified only by reading the code and with real mouse-wheel events;
      test with a precision touchpad on Windows and a trackpad on macOS: two-finger scroll must not zoom, and a
      deliberate pinch must.
- [ ] **Drag and drop a file onto the window** (desktop). Read through but never dropped for real.
- [ ] **Foldables.** Posture handling is covered by widget tests only. Run on the Fold emulators and Samsung
      Remote Test Lab: Flip half-open (tabletop), Fold book posture, launch folded then unfold, rotate while
      unfolded, split-screen. Plan: `agentic/data/design/FOLDABLES-PLAN.md`.
- [ ] **Android rotation.** The portrait lock is gone; check every screen on a phone in landscape, not only the home
      screen and the readers I checked on Windows window sizes.

## Tabs and side by side (built on Windows; plan: `agentic/data/design/WORKSPACE-PLAN.md`)

- [ ] Right-click tab menu ("Show in left / right pane", "Split right", close others) and drag to reorder were
      built but not exercised by hand. Shortcuts (Ctrl+W, Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+\, Ctrl+B) and middle-click
      close were tested live.
- [ ] The split (which tab is on which side, the ratio) is not remembered across a restart; the tabs and the active
      one are.
- [ ] Home details pane: "Show in folder" and "Copy path" were not clicked in the live test (Open, Beside and
      Up / Down selection were).
- [ ] Opening a file from another process while the app runs works on Windows only. Linux (a `GApplication` is
      non-unique, so a second window opens) and macOS (a second launch is the OS's job) are not wired.
- [ ] Tabs on phones and small tablets (today they open one screen at a time).
- [ ] More than two panes, and dragging a tab out into its own window.
- [ ] Every tab keeps its reader mounted (PDF engine included), up to 12; measure memory with several large PDFs.

## Layout and reader work still to do

- [ ] Two-pane (list plus details) exists on Home only, from about 1000 px of content width. Add it to Library and
      History, and lower the threshold so an unfolded Fold's inner screen gets it too (FOLDABLES-PLAN P3). Opening
      a document still goes full screen; showing the reader in the right pane is not done.
- [ ] **Dedicated tablet reader UI**: toolbar placement and navigation panels for portrait and landscape.
- [ ] **Mobile reader polish**: fit-to-width by default, double-tap to zoom and reset, compact toolbar, no horizontal
      overflow.
- [ ] **One document-viewing design system** across desktop, tablet and phone (Acrobat-style), once the pieces above
      are in.
- [ ] Word document view: draw real page edges (A4 sheet with margins) instead of a wide text column.
- [ ] Reader app bars could be shorter in landscape (56 dp now).

## Icons and packaging

- [ ] **macOS DMG: run it on a Mac.** `macos/dmg/make-dmg.sh` was written without a Mac. Build with
      `flutter build macos --release`, then `brew install create-dmg` and
      `macos/dmg/make-dmg.sh build/macos/Build/Products/Release/OpenReader.app /tmp/OpenReader.dmg 1.0.11`.
      Check: the window opens with the background, the app icon sits on the left of the arrow and the Applications
      shortcut on the right (positions in `make-dmg.sh` and `tool/generate_dmg_background.ps1` must agree), dragging
      works, and the app starts from Applications. Also try it without create-dmg to see the plain fallback.
- [ ] **Linux packages: install them on real distributions.** `.deb` (Ubuntu 22.04 and 24.04, Debian 12), `.rpm`
      (Fedora, openSUSE) and the AppImage. `tool/test_linux_packages.sh` tests the packaging in containers with a
      stand-in app (Docker could not start on the Windows machine this was written on); a real install also checks
      that the declared dependencies (`libjsoncpp` has different names per release) resolve and the app launches.
- [ ] Sign and notarise the macOS app and DMG (Apple Developer ID), and sign the Linux packages (GPG), so Gatekeeper
      and package managers stop warning. Add a package repository (apt / dnf) if updates should not be manual.
- [ ] The packages and AppStream file say the licence is unspecified: the repository has no LICENSE file. Pick one.
- [ ] Linux arm64 packages (a `ubuntu-24.04-arm` runner) and an Intel-only check of the macOS universal build.

- [ ] **macOS per-type document icons.** The Windows set exists; macOS needs `.icns` files wired into the Xcode
      project (`CFBundleTypeIconFile` per type). Linux file managers use the theme's own icons.
- [ ] Linux: set the running window's icon in the runner (the launcher and file-manager icons are covered).
- [ ] A 1024 px export of `assets/icon/icon.svg` for the macOS icon (it is upscaled from 512 px now).
- [ ] An installer (Inno Setup / MSIX) that registers file types and a Start menu entry, instead of the
      `register-file-types.ps1` script.
- [ ] Legacy `.doc`, `.xls`, `.ppt` are not registered or opened on any platform.

## Housekeeping

- [ ] The kit marks its scroll controllers `@internal`, and the Word, text, Excel and CSV readers use them for the
      desktop scrollbars behind an `ignore` comment. Expose them publicly in `universal_document_viewer`.
