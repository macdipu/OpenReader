# OpenReader cross-platform UI audit

Date: 2026-10-30 · App version: 1.0.11+13 · Flutter 3.47.9

## How this was done (and what it cannot tell you)

Every screenshot in `shots/` is a capture of the real app, not a mock-up.

| Surface | How it was exercised |
|---|---|
| Windows 11 | `flutter build windows --release`, window resized from 460×820 to 1440×860 with `tool/capture_window.ps1` |
| Android phone | Debug build on an Android 17 x86_64 emulator, 1080×2340 @ 440 dpi |
| Android tablet | Same emulator, `adb shell wm size 2560x1600` + `wm density 320` (1280×800 dp) |
| Android foldable, unfolded | Same emulator, `wm size 2208x1840` + `wm density 420` (≈ 840×700 dp) |
| Dark theme | Android night mode (`cmd uimode night yes`) |

**Not tested** (no hardware or OS available in this session):

- **macOS** and **Linux**: the release workflow builds them, but they were not run here. The laptop frame on the
  landing page shows the Windows build's interface with its title bar removed, and the page says so.
- **iOS / iPadOS**: OpenReader is not published for iOS (`README.md` lists Android, Windows, macOS, Linux). Nothing
  here claims iOS support.
- **Real tablets and foldables**: the emulator size override reproduces dp width, density and status-bar insets, but
  not hinge geometry or posture changes. Fold posture handling stays covered by widget tests only (see `docs/TODO.md`).
- TalkBack / Narrator / VoiceOver screen-reader passes, and keyboard-only passes on desktop.

## Platform compatibility matrix

| Platform / form factor | Shipped by release workflow | Layout (width class) | Audited in this pass |
|---|---|---|---|
| Windows 10+ x64 desktop | zip | expanded (≥ 1024 dp): side rail, tabs | Yes: real build |
| Windows, narrow window | zip | compact / medium: bottom bar, then rail | Yes: 460, 900, 1100, 1280, 1440 px |
| macOS 12+ laptop | `.dmg` | expanded | **No**: not run |
| Linux x64 (GTK 3) | `.deb`, `.rpm`, AppImage, `.tar.gz` | expanded | **No**: not run |
| Android phone | APK, Google Play | compact: bottom bar | Yes: emulator |
| Android tablet | APK, Google Play | expanded: side rail, tabs | Yes: emulator size override |
| Android foldable (unfolded) | APK, Google Play | medium/expanded: collapsed rail | Yes: emulator size override |
| Android foldable (folded, tabletop, book) | same | compact / fold-aware | **No**: widget tests only |
| iOS / iPadOS | not shipped | n/a | n/a |

## Findings, most severe first

| # | Severity | Finding | Where | Status |
|---|---|---|---|---|
| 1 | High | The side rail's logo and the workspace tab strip were drawn **under the Android status bar** on tablets and foldables: the clock overlapped "OpenReader" and the first tab was clipped. | `desktop_sidebar.dart`, `workspace_view.dart` | **Fixed**: rail and tab strip now add the system insets; readers under the strip no longer add the gap a second time (screenshots `tablet-pdf.png`, `fold-pdf.png`) |
| 2 | Medium | Touch tablets showed a **`Ctrl+O`** hint on "Open file". | `desktop_sidebar.dart` | **Fixed**: hint hidden on Android/iOS |
| 3 | Medium | "Make OpenReader your default reader?" on a phone stacked its three buttons with mixed alignment, putting the primary action last. | `default_app_dialog.dart` | **Fixed**: one right edge, primary action first |
| 4 | Low | Onboarding listed "PDF, Word, Excel, PowerPoint, Text, and CSV" and omitted Markdown, which the app opens. | `onboarding_view.dart` | **Fixed** |
| 5 | Low | Dark theme uses true black (AMOLED) for the page and a navy for bars and navigation, so the two surfaces look slightly mismatched on Browse. | `color_schemes.dart` | Open: deliberate AMOLED choice, left for a design decision |
| 6 | Low | Opening a file from the command line into a window that is already narrow (460 px) landed on Home instead of the document in one run. Not reproduced twice. | workspace / launch args | Open: needs a repro |
| 7 | Info | Word reader on desktop left-aligns the page content with a wide empty right side at 1280 px. | document engine (`universal_document_viewer`) | Open: lives in the dependency |
| 8 | Info | Two flows use a monospace face for small labels ("Just now", bottom-nav label). Consistent, but unusual next to Inter. | `text_theme.dart` | Open: style decision |

## Things that were already good

- Navigation changes with window size, not platform: bottom bar < 600 dp, rail ≥ 600 dp, rail collapsed to icons on a
  foldable's inner screen (`ScreenUtils`).
- Reader chrome keeps a single floating toolbar at every size.
- Light and dark themes both read clearly on the screens captured (no contrast measurement was run).
- Content width is capped for reading rather than stretched on large windows.

## Verification

- `flutter analyze` on the touched folders: no new issues (pre-existing infos only).
- `flutter test test/widgets`: 71 passed. Full suite: 263 passed, 1 failed:
  `document_thumbnail_service_test` ("cache files … oldest pruned past the cap"), which **fails identically with the
  changes stashed**, so it is not caused by this work.
- Before/after captures of findings 1–3 are `shots/tablet-home.png`, `shots/fold-home.png` (before) and
  `shots/tablet-pdf.png`, `shots/fold-pdf.png`, `shots/phone-pdf.png` (after).

## Regenerating the screenshots

```
flutter build windows --release
powershell -ExecutionPolicy Bypass -File tool/capture_window.ps1 -Width 1440 -Height 860 `
  -Out docs/ui-audit/shots/win-1440-pdf.png -File "tool/screenshot_samples/Exploring the World.pdf"
# Android: install the debug APK, adb push tool/screenshot_samples/* /sdcard/Documents/, then adb exec-out screencap -p
powershell -ExecutionPolicy Bypass -File tool/make_device_assets.ps1   # writes docs/assets/devices/*
```

The sample document `Exploring the World` (`tool/screenshot_samples/make_showcase_samples.ps1`) is drawn from scratch,
so every device shows the same content with nothing to license.
