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

The page (`index.html`) is OS-aware and falls back to the Windows screenshots, with a visible note, for any platform
whose images are missing. Add the files and it picks them up with no code change.

macOS and Linux screenshots still need capturing on a real machine (Windows and Android are done):

| File (in `docs/assets/screens/`) | What |
|---|---|
| `macos-pdf.png`, `macos-docx.png`, `macos-docx-dark.png`, `macos-xlsx.png` | macOS |
| `linux-pdf.png`, `linux-docx.png`, `linux-docx-dark.png`, `linux-xlsx.png` | Linux |

How to capture (keeps all platforms consistent):

1. Build and run the release app (`flutter build macos --release` / `flutter build linux --release`).
2. Finish onboarding, then open the files in `tool/screenshot_samples/` (neutral sample content, safe to publish):
   `Quarterly Report.pdf`, `Project Atlas Brief.docx`, `Sales 2026.xlsx`.
3. Use a window of about 1280x760, light theme first.
   - `*-pdf.png`: PDF reader. `*-docx.png`: Word. `*-xlsx.png`: Excel.
   - `*-docx-dark.png`: the Word file with night mode on (moon button in the bottom bar).
4. Capture the window only (macOS: `Cmd+Shift+4`, Space, click the window; Linux: your screenshot tool's window
   mode). Crop transparent shadow edges; keep the native title bar.
5. Save as PNG (about 1262x750), under about 150 KB each (`pngquant` is fine).

- [ ] Link each platform button straight to its release asset instead of `releases/latest`, once file names are stable.
- [ ] Add a macOS-style and Linux-style window frame if the native title bars look inconsistent side by side.
- [ ] `docs/` is the published site, so this file is served publicly. Move it to the repo root if that is not wanted.

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

## Layout and reader work still to do

- [ ] **Two-pane layout** for tablets and a Fold's inner screen: list on one side, reader on the other
      (FOLDABLES-PLAN P3). Home and Library are single lists today.
- [ ] Home's "Continue Reading" shows three cards and leaves space on wide tablets and desktop.
- [ ] **Dedicated tablet reader UI**: toolbar placement and navigation panels for portrait and landscape.
- [ ] **Mobile reader polish**: fit-to-width by default, double-tap to zoom and reset, compact toolbar, no horizontal
      overflow.
- [ ] **One document-viewing design system** across desktop, tablet and phone (Acrobat-style), once the pieces above
      are in.
- [ ] Word document view: draw real page edges (A4 sheet with margins) instead of a wide text column.
- [ ] Reader app bars could be shorter in landscape (56 dp now).
- [ ] Spreadsheet readers: a horizontal scrollbar on desktop (only vertical exists).

## Icons and packaging

- [ ] **macOS per-type document icons.** The Windows set exists; macOS needs `.icns` files wired into the Xcode
      project (`CFBundleTypeIconFile` per type). Linux file managers use the theme's own icons.
- [ ] Linux: set the running window's icon in the runner (the launcher and file-manager icons are covered).
- [ ] A 1024 px export of `assets/icon/icon.svg` for the macOS icon (it is upscaled from 512 px now).
- [ ] An installer (Inno Setup / MSIX) that registers file types and a Start menu entry, instead of the
      `register-file-types.ps1` script.
- [ ] Legacy `.doc`, `.xls`, `.ppt` are not registered or opened on any platform.

## Housekeeping

- [ ] Two `pdf_reader_controller_test.dart` tests fail on most full runs, a different pair each time (also seen
      before the recent changes). Likely shared state or timing; find and fix.
- [ ] Single-instance handling on desktop: opening a file while OpenReader is running starts a second window.
