# Landing page TODO

The landing page (`index.html`) is OS-aware: it detects Android / Windows / macOS / Linux, leads with that
platform's download and screenshots, and falls back to the Windows screenshots (with a visible note) for any
platform whose images are missing. Add the files below and the page picks them up with no code change.

## Screenshots still needed

Windows and Android are done. macOS and Linux need capturing on a real machine.

| File (in `docs/assets/screens/`) | What | Status |
|---|---|---|
| `desktop-pdf.png`, `desktop-docx.png`, `desktop-docx-dark.png`, `desktop-xlsx.png` | Windows | done |
| `phone-files.png` | Android file list | done |
| `macos-pdf.png`, `macos-docx.png`, `macos-docx-dark.png`, `macos-xlsx.png` | macOS | **TODO** |
| `linux-pdf.png`, `linux-docx.png`, `linux-docx-dark.png`, `linux-xlsx.png` | Linux | **TODO** |

How to capture (keeps all platforms visually consistent):

1. Build and run the release app (`flutter build macos --release` / `flutter build linux --release`).
2. Finish onboarding, then open the files in `tool/screenshot_samples/` (neutral sample content, safe to publish):
   `Quarterly Report.pdf`, `Project Atlas Brief.docx`, `Sales 2026.xlsx`.
3. Use a window of about 1280x760 so the page layout matches, light theme first.
   - `*-pdf.png`: the PDF reader. `*-docx.png`: Word. `*-xlsx.png`: Excel.
   - `*-docx-dark.png`: the Word file with night mode on (moon button in the bottom bar).
4. Capture the window only (macOS: `Cmd+Shift+4`, then Space, then click the window; Linux: your screenshot tool's
   "window" mode). Crop transparent shadow edges; keep the native title bar.
5. Save as PNG (about 1262x750), under about 150 KB each (`pngquant` is fine).

## Other

- [ ] Verify the macOS "Open With" and Linux `install-desktop-entry.sh` flows on real machines, then re-check the
      copy in the "Desktop integration" and "Download" sections.
- [ ] Link each platform button directly to its release asset instead of `releases/latest` once file names are stable.
- [ ] Add a macOS-style and Linux-style window frame if the native title bars look inconsistent next to each other.

## "Make OpenReader the default app" (in-app prompt + Settings > Default app)

Built and verified on Windows (opens Settings > Default apps on OpenReader's page, which lists each file type).
Not yet run on the other platforms:

- [ ] **macOS**: `setDefaultForExtensions` in `macos/Runner/AppDelegate.swift` (`NSWorkspace.setDefaultApplication`, macOS 12+).
      Check the confirmation prompt, that a declined type is reported, and that Finder's Open With reflects the change.
- [ ] **Linux**: `xdg-mime default` per MIME type, after `install-desktop-entry.sh` if the entry is missing. Test on GNOME and KDE.
- [ ] **Android**: opens the system default-apps screen (`MainActivity.kt`). Check on Android 10 through 15 that the
      screen opens, then that choosing OpenReader and tapping Always works for a PDF.
