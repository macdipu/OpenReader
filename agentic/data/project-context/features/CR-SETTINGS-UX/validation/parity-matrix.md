# CR-SETTINGS-UX: Settings feature-parity matrix

Source of truth: `lib/features/settings/presentation/` as of 2026-11-21 (standard-UX pass). Platform
is `defaultTargetPlatform` (`PlatformInfo`); layout follows window width, not platform.

Legend: **shown** = same item and behaviour; **adapted** = present but different on that platform (see
note); **hidden** = not rendered.

## Layout and shared behaviour

| Item | Android | iOS | macOS | Windows | Linux | Note |
|---|---|---|---|---|---|---|
| Section order | adapted | adapted | adapted | adapted | adapted | Mobile: Permissions, Reading, Appearance, Files & storage, Privacy, Open with, Help & about. Desktop: File handling, Reading, Appearance, Files & storage, Privacy, Keyboard shortcuts, Help & about (`settingsSectionsForPlatform`). |
| Single column (< 900px) | shown | shown | shown | shown | shown | Sentence-case section headers, announced as headings. |
| Two panes (>= 900px) | shown | shown | shown | shown | shown | Tablets and wide desktop windows. Selected item: filled background, leading indicator bar, bold text, `selected` semantics. List is one Tab stop; Up/Down/Home/End move the selection; 2px focus ring on keyboard focus only; items >= 44dp. |
| Picker for 4+ options | adapted | adapted | adapted | adapted | adapted | Android/iOS: modal bottom sheet with radio options. Desktop: dialog with radio options and Cancel. Applies on pick. |
| Destructive confirm + success snackbar | shown | shown | shown | shown | shown | Clear history, clear render cache, reset all: confirm button in `colorScheme.error`, then a snackbar saying what happened. |

## Items

| Section / item | Android | iOS | macOS | Windows | Linux | Note |
|---|---|---|---|---|---|---|
| **Permissions** section | shown | adapted | hidden | hidden | hidden | iOS has no storage permission, so no status. |
| File access row (Allowed / Not allowed / Blocked) | shown | hidden | hidden | hidden | hidden | One compact row: icon, "File access", status chip (icon + text) on the title line, one supporting line. Allowed: the row opens the OS page to manage, no note, no help. Not allowed or Blocked: adds a full-width "Allow file access" button. Refreshes on resume, then re-checks at 0.7 s, 1.5 s and 3 s until it changes. Android 11+ shows Allowed / Not allowed only (All files access); Blocked appears on Android 10 and older only. Hidden when the state cannot be read. |
| Fix-access action (Manage / Allow / Open settings to allow) | shown | hidden | hidden | hidden | hidden | Matches the state; Blocked explains first, then opens All files access. |
| Limited-mode note | shown (not allowed or blocked only) | hidden | hidden | hidden | hidden | One-line caption under the button; never shown when Allowed. |
| How to allow it yourself | shown (not allowed or blocked only) | hidden | hidden | hidden | hidden | Text button; opens a bottom sheet (dialog from 600 px) with the steps, "Open All files access" and "Open app settings". |
| App permissions (opens OS app settings) | adapted | shown | hidden | hidden | hidden | Android: only when the status cannot be read. iOS: always, with a Files/Share-sheet note. |
| **File handling** section | hidden | hidden | shown | shown | shown | `DefaultAppService.isSupported` = desktop. |
| Per-type status (Default / Other app) + Set | hidden | hidden | adapted | adapted | adapted | Icon + text (check / neutral outline). macOS: method channel, re-read 1.5 s after Set. Windows: registry `UserChoice` (types it cannot read show Set without status). Linux: `xdg-mime query default`. |
| Set all | hidden | hidden | shown | shown | shown | Action row, no chevron. |
| Open system default-apps settings | hidden | hidden | hidden | shown | hidden | Windows only; external icon. |
| Ask me again (first-run prompt) | hidden | hidden | shown | shown | shown | Action row, no chevron; success snackbar. |
| **Reading**: PDF default view | shown | shown | shown | shown | shown | Segmented (2 options). |
| Night mode | shown | shown | shown | shown | shown | Switch row, whole row toggles. |
| Text size with live preview | shown | shown | shown | shown | shown | Stepper 48dp buttons. |
| Wrap long lines | shown | shown | shown | shown | shown | Switch row. |
| Restore last position | shown | shown | shown | shown | shown | Switch row. |
| Keep screen awake (ST-16) | shown | shown | shown | shown | shown | Switch row, default off. Holds the wakelock only while a reader is visible and the app is in the foreground. |
| **Appearance**: Theme (Light / Dark / System) | shown | shown | shown | shown | shown | Segmented (3 options). |
| Dynamic colour (ST-20) | adapted | hidden | adapted | adapted | adapted | Switch row, default off, shown only when the system reports a palette. Android 12+: "Use wallpaper colours" (hidden before 12). macOS / Windows / GTK Linux: "Use accent colour". iOS: no palette, hidden. Theme rebuilds live. |
| **Files & storage**: Clear reading history | shown | shown | shown | shown | shown | Confirm (error colour), success snackbar. |
| Keep reading history (Forever / 30 days / Off) | shown | shown | shown | shown | shown | Segmented (3 options); Off asks first. |
| Render cache size + Clear render cache | shown | shown | shown | shown | shown | Confirm (error colour), snackbar names bytes freed. |
| Cache size limit (No limit / 100 MB / 500 MB / 1 GB) | adapted | adapted | adapted | adapted | adapted | Row with current value + chevron; bottom sheet on mobile, dialog on desktop. |
| **Privacy**: statement | shown | shown | shown | shown | shown | Firebase crash reports and analytics, tied to a random installation identifier; two short sentences. |
| Privacy policy (ST-06, Q2) | shown | shown | shown | shown | shown | Action row with external-link icon; opens `https://macdipu.github.io/OpenReader/privacy.html`; error snackbar if it can't open. |
| Hide thumbnails | shown | shown | shown | shown | shown | Switch row. |
| **Open with** tip | adapted | adapted | hidden | hidden | hidden | Android: file manager "Open with"/"Always". iOS: Files app Share sheet. |
| **Keyboard shortcuts** list | hidden | hidden | adapted | shown | shown | Read-only; macOS shows Cmd, others Ctrl. Includes Ctrl/Cmd+, (Open Settings). |
| **Help & about**: Send feedback | shown | shown | shown | shown | shown | Opens a pre-filled GitHub issue (version, OS, platform; no file data). |
| Rate OpenReader | shown | hidden | hidden | hidden | hidden | Play Store URL known only for Android. |
| Share app | shown | shown | shown | shown | shown | Share sheet; text has the Play Store link. |
| Show welcome screens again | shown | shown | shown | shown | shown | Confirm, success snackbar. |
| Reset all settings | shown | shown | shown | shown | shown | Confirm (error colour), success snackbar. |
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
