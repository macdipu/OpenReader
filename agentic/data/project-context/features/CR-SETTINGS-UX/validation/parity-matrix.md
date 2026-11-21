# CR-SETTINGS-UX: Settings feature-parity matrix

Source of truth: `lib/features/settings/presentation/` as of 2026-11-21 (standard-UX pass). Platform
is `defaultTargetPlatform` (`PlatformInfo`); layout follows window width, not platform.

Legend: **shown** = same item and behaviour; **adapted** = present but different on that platform (see
note); **hidden** = not rendered.

## Layout and shared behaviour

| Item | Android | iOS | macOS | Windows | Linux | Note |
|---|---|---|---|---|---|---|
| Section order | adapted | adapted | adapted | adapted | adapted | Mobile: File access, Reading, Appearance, Privacy & data, About. Desktop: File handling, Reading, Appearance, Privacy & data, Keyboard shortcuts, About (`settingsSectionsForPlatform`). Redesign 2026-11-21: Data, Privacy and Open with sections merged away; one row style everywhere (plain 24dp icon, title, one supporting line, trailing control; 56dp with a supporting line, 48dp without; inset dividers). |
| Single column (< 900px) | shown | shown | shown | shown | shown | Sentence-case section headers, announced as headings. |
| Two panes (>= 900px) | shown | shown | shown | shown | shown | Tablets and wide desktop windows. Selected item: filled background, leading indicator bar, bold text, `selected` semantics. List is one Tab stop; Up/Down/Home/End move the selection; 2px focus ring on keyboard focus only; items >= 44dp. |
| Picker for 4+ options | adapted | adapted | adapted | adapted | adapted | Android/iOS: modal bottom sheet with radio options. Desktop: dialog with radio options and Cancel. Applies on pick. |
| Destructive confirm + success snackbar | shown | shown | shown | shown | shown | Clear history, clear render cache, reset all: confirm button in `colorScheme.error`, then a snackbar saying what happened. |

## Items

| Section / item | Android | iOS | macOS | Windows | Linux | Note |
|---|---|---|---|---|---|---|
| **File access** section (id `fileAccess`) | shown | adapted | hidden | hidden | hidden | iOS has no storage permission, so no status. |
| File access row (Allowed / Not allowed / Blocked) | shown | hidden | hidden | hidden | hidden | One compact row: icon, "File access", status chip (icon + text) on the title line, one supporting line when not allowed. Allowed: a single row with no supporting line (accessibility label "Manage file access"); it opens the All files access page (app settings on Android 10 and older), no note, no help. Not allowed or Blocked: adds a full-width "Allow file access" button. Refreshes on resume, then re-checks at 0.7 s, 1.5 s and 3 s until it changes. Android 11+ shows Allowed / Not allowed only (All files access); Blocked appears on Android 10 and older only. Hidden when the state cannot be read. |
| Fix-access action (Manage / Allow / Open settings to allow) | shown | hidden | hidden | hidden | hidden | Matches the state; Blocked explains first, then opens All files access. |
| Limited-mode note | shown (not allowed or blocked only) | hidden | hidden | hidden | hidden | One-line caption under the button; never shown when Allowed. |
| How to allow it yourself | shown (not allowed or blocked only) | hidden | hidden | hidden | hidden | Text button; opens a bottom sheet (dialog from 600 px) with the steps and one filled button: "Open All files access" on Android 11+ (never the app info page, which has no such switch), "Open app settings" on Android 10 and older. |
| App permissions (opens OS app settings) | adapted | shown | hidden | hidden | hidden | Android: only when the status cannot be read. iOS: always, with a Files/Share-sheet note. |
| **File handling** section | hidden | hidden | shown | shown | shown | `DefaultAppService.isSupported` = desktop. |
| Per-type status (Default / Other app) + Set | hidden | hidden | adapted | adapted | adapted | Icon + text (check / neutral outline). macOS: method channel, re-read 1.5 s after Set. Windows: registry `UserChoice` (types it cannot read show Set without status). Linux: `xdg-mime query default`. |
| Set all | hidden | hidden | shown | shown | shown | Action row, no chevron. |
| Open system default-apps settings | hidden | hidden | hidden | shown | hidden | Windows only; external icon. |
| Ask me again (first-run prompt) | hidden | hidden | shown | shown | shown | Action row, no chevron; success snackbar. |
| **Reading**: PDF default view | hidden | hidden | hidden | hidden | hidden | Removed from Settings (user, 2026-11-21): the PDF reader's toolbar owns the mode; the saved preference and its live sync stay. |
| Night mode | shown | shown | shown | shown | shown | Switch row, whole row toggles; supporting line "Dark pages in every reader". |
| Text size | shown | shown | shown | shown | shown | Stepper only (label left, [-] 16 pt [+] right, 48dp buttons); the sample sentence was removed 2026-11-21. |
| Wrap long lines | shown | shown | shown | shown | shown | Switch row. |
| Restore last position | shown | shown | shown | shown | shown | Switch row. |
| Keep screen awake (ST-16) | shown | shown | shown | shown | shown | Switch row, default off. Holds the wakelock only while a reader is visible and the app is in the foreground. |
| **Appearance**: Theme (Light / Dark / System) | shown | shown | shown | shown | shown | One row: "Theme" with a full-width text-only 3-segment control (Light, Dark, System; 48dp) under it, no icons. |
| Dynamic colour (ST-20) | adapted | hidden | adapted | adapted | adapted | Switch row, default off, shown only when the system reports a palette. Android 12+: "Use wallpaper colours" (hidden before 12). macOS / Windows / GTK Linux: "Use accent colour". iOS: no palette, hidden. Theme rebuilds live. |
| **Privacy & data**: Clear all history (ST-07) | shown | shown | shown | shown | shown | Action row; confirm (error colour), success snackbar. |
| **Privacy & data**: Reset all settings | shown | shown | shown | shown | shown | Action row, title in the error colour, moved here from Help & about on 2026-11-21; confirm text says "reading, appearance and privacy choices" (error colour), success snackbar. |
| Keep reading history (Forever / 30 days / Off) (ST-11/ST-12) | removed | removed | removed | removed | removed | Removed by the user on 2026-11-21; no UI, no code in the settings layer. |
| Render cache size + Clear render cache (ST-11/ST-12) | removed | removed | removed | removed | removed | Removed by the user on 2026-11-21; no UI, no code in the settings layer. |
| Cache size limit (No limit / 100 MB / 500 MB / 1 GB) (ST-11/ST-12) | removed | removed | removed | removed | removed | Removed by the user on 2026-11-21; no UI, no code in the settings layer. |
| **Privacy & data**: statement | shown | shown | shown | shown | shown | Footnote under the card (two lines max): documents never uploaded; crash reports and usage analytics tied to a random installation ID are sent to Google Firebase. |
| Privacy policy (ST-06, Q2) | shown | shown | shown | shown | shown | First row of the Privacy & data card; action row with external-link icon; opens `https://macdipu.github.io/OpenReader/privacy.html`; error snackbar if it can't open. |
| Hide thumbnails | shown | shown | shown | shown | shown | Switch row, "Show file icons instead of page previews". |
| Open with tip | adapted | adapted | hidden | hidden | hidden | A footnote under the About card (no section of its own since 2026-11-21). Android: file manager "Open with"/"Always". iOS: Files app Share sheet. |
| **Keyboard shortcuts** list | hidden | hidden | adapted | shown | shown | Read-only; macOS shows Cmd, others Ctrl. Includes Ctrl/Cmd+, (Open Settings). |
| **About**: Send feedback | shown | shown | shown | shown | shown | Opens a pre-filled GitHub issue (version, OS, platform; no file data). |
| Rate OpenReader | shown | hidden | hidden | hidden | hidden | Play Store URL known only for Android. |
| Share app | shown | shown | shown | shown | shown | Share sheet; text has the Play Store link. |
| Show welcome screens again | shown | shown | shown | shown | shown | Confirm, success snackbar. |
| Reset all settings | removed | removed | removed | removed | removed | Moved to Privacy & data on 2026-11-21 (see above). |
| Version | shown | shown | shown | shown | shown | Read-only. |
| Open-source licenses | shown | shown | shown | shown | shown | Navigates (chevron). |

## Not verifiable in widget tests

- Real screen-reader output (TalkBack, VoiceOver, Narrator, Orca) for merged rows and selected state.
- Windows `UserChoice` read and macOS channel status on real machines.
- Bottom-sheet behaviour with system gesture navigation and the iOS home indicator.
- Keep screen awake: that the screen really stays on past the OS timeout while reading, and sleeps
  normally after leaving the reader or backgrounding the app (each OS, real device).
- Dynamic colour: the real wallpaper palette on Android 12+ and accent colour on macOS / Windows /
  Linux, the switch staying hidden on Android 11 and iOS, and a wallpaper/accent change while the app
  runs (the palette is read once at start).
