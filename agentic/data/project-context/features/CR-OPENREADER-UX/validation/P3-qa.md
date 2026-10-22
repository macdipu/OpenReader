# CR-OPENREADER-UX Phase 3: QA (2026-10-22, revision 1)

## Android emulator (Pixel 4a, debug build of revision 1)
Screenshots are in `qa-p3/`.

| Check | Result | Evidence |
|---|---|---|
| UX-34: phone "Open file" | PASS. Home ⋮ shows "Open file", which opens the system document picker. | `q3-11`, `q3-12` |
| UX-23: privacy copy | PASS. Settings shows the OFFLINE pill. The storage text names All Files Access and says files are deleted only when you choose Delete. | `q3-13` |
| UX-25: highlight and dates | PASS. Search highlights "qa-re" in `qa-report.pdf`; the date reads "Oct 21, 2026". | `q3-14` |
| UX-33: PDF toolbar | PASS. Zoom out, zoom in, fit width and fullscreen are present, and the page is clear of the toolbar. | `q3-15` |
| UX-33 / P3-review #2/#3: night mode | PASS. Toggling night mode keeps page 4. The thumbnails are inverted, and the strip shows the current page highlighted. | `q3-17`, `q3-18` |
| UX-33: fullscreen | PASS. The system bars and controls hide (Android shows its "Viewing full screen" hint), and a tap restores them. | `q3-19`, `q3-20` |
| UX-32 / P3-review #1: grid zoom | PASS. After scrolling to row 9, zooming to 125% keeps row 9 at the top, and the frozen column stays in sync. | `q3-22`, `q3-23` |
| UX-32: cell detail | PASS. Tapping a cell shows "Cell A12", "item10" and Copy. | `q3-24` |

## macOS (debug build)
- **What was checked:** `flutter build macos --debug` succeeds with `desktop_drop` registered. The app launches and keeps running, with no crash.
- **Not verifiable here:** the desktop welcome screen, drag-and-drop, the keyboard shortcuts and right-click. Screen Recording permission is unavailable to this session, and Flutter's macOS accessibility tree is only built when a screen reader is active. These behaviours are covered by widget tests only (`ux_phase3_test` group D and the onboarding desktop variants).

## Tests
- `flutter test`: 220/220 pass.
- `flutter analyze --no-fatal-infos`: 0 errors, 1 pre-existing warning.
