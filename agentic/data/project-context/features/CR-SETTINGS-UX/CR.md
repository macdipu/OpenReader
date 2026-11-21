# CR-SETTINGS-UX: a useful Settings page on mobile and desktop

Status: **DRAFT, awaiting the user's approval.** No implementation before approval. No harness run registered yet (CR-OWN-ENGINES, `RUN-60D2C2882A324C15AAD0FBB0A9DC42DF`, is still open at REVIEW).
Owner repo: **OpenReader only.** Nothing here is generic document viewing, so the Kit (`universal_document_viewer`) is not changed (AGENTS.md §1). The one Kit-dependent idea (default page fit and zoom) is listed under Out of Scope.
Traceability: BRD §9.2 (Storage Access), BRD §9.18 (Settings Screen), DESIGN_SPEC #01. Requirement IDs `ST-xx` below are the anchors for tasks, tests and QA.

## Current Behavior
`lib/features/settings/presentation/settings_view.dart` shows:
- **Appearance:** Light / Dark / System.
- **Default app:** desktop only (`DefaultAppService.isSupported => isDesktop`). A button that opens the chooser dialog, with no indication of the current default.
- **Cache:** render-cache size and a Clear button.
- **About:** version and open-source licenses.

On Android and iOS that leaves three cards. Gaps against BRD §9.18 and the code:
- No **Reader** section. These preferences are already saved in `AppSettingsRepository` but can only be changed inside a reader: `defaultContinuousScroll`, `readerNightMode`, `textReaderFontSize`, `textReaderLineWrap`.
- No **Files** section: Clear Recent history lives only in Library's History.
- No **Privacy** section and no Privacy Policy link.
- No way to see or fix **file access**. `StorageAccessService` has `hasAccess`, `isPermanentlyDenied`, `requestOrOpenSettings` and `openSettings`, but Settings uses none of them.
- **Telemetry:** release builds always enable Firebase Analytics and Crashlytics (`lib/app/flavours/app_flavour.dart:49-50`), and the user has no way to turn them off. That conflicts with the BRD's "explain local-only processing" unless it is disclosed.
- Desktop: a loose two-column grid. No list of keyboard shortcuts and no Ctrl/Cmd+, shortcut.

## Requested Change
Plan Settings for mobile and desktop (user, 2026-11-21): add permission settings navigation, research what can be added, and on Windows and Linux show the default-app option in the permission slot.

## Reason
Settings currently doesn't help the user. Reading preferences are hidden inside readers, a missing file permission (the most common reason the app looks empty) can't be found or fixed, and data use isn't disclosed.

## In Scope

### Phase 1 (Must, no new dependencies)
| ID | Requirement | Platforms |
|---|---|---|
| ST-01 | **Permissions section:** live file-access status (Allowed / Not allowed (limited mode) / Blocked). The action matches the state: request, explain then open OS settings, or open app settings to revoke. Status refreshes on app resume (reuse the shell's existing resume re-check). Includes a short "what limited mode means" note. | Android |
| ST-02 | **Permissions section:** "App permissions" opens `openAppSettings()`, with a note that files come from the Files app or the Share sheet. No status shown, because iOS has no storage permission. | iOS |
| ST-03 | **File handling section:** each document type (PDF, Word, Excel, PowerPoint, CSV, Text, Markdown) shows ✅ Default or ○ Other app, with Set per type, Set all, and a link to system settings where one exists. Reuses `DefaultAppService.makeDefault`. Status comes from a new `queryDefaults()`: Linux `xdg-mime query default <mime>`; Windows `reg query` of `UserChoice\ProgId` after a spike; if Windows can't be read reliably, show the button without status. Status refreshes on resume. The Linux missing-`xdg-utils` message is kept. | Windows, Linux |
| ST-04 | **Reading section:** night mode for readers; text font size with a live preview; line wrap. Each value stays in sync with the reader toolbars in both directions. | All |
| ST-05 | **Restore last reading position:** an on/off switch (default on, which is today's behaviour). When off, readers open at the start; saved positions are kept but not applied. | All |
| ST-06 | **Privacy section:** a factual statement that documents are processed on the device and never uploaded, and that anonymous crash reports and usage analytics are always collected and sent to Google Firebase in release builds (debug builds send nothing). Decided 2026-11-21: always on, no switches, no opt-in or opt-out. **Privacy policy link done 2026-11-21 (Q2):** a "Privacy policy" row below the statement opens `https://macdipu.github.io/OpenReader/privacy.html` (external-link icon, error snackbar "Could not open the privacy policy." when it can't open), on every platform. Startup behaviour is unchanged (`setCrashlyticsCollectionEnabled(!kDebugMode)`, `setAnalyticsCollectionEnabled(!kDebugMode)`). | All |
| ST-07 | **Data** (was Data): Clear all history (confirmation), and Reset all settings (moved from Help & about). The render cache description was **removed by the user on 2026-11-21**. | All |

### Phase 2 (Should, no new dependencies)
| ID | Requirement | Platforms |
|---|---|---|
| ST-08 | **Desktop two-pane layout** (≥900px): section list on the left, content on the right; arrow keys move between sections, Tab moves through controls. 600–900px uses the mobile single column. | Desktop |
| ST-09 | **Keyboard shortcuts section:** read-only list taken from `app_shortcuts.dart`, plus a new **Ctrl/Cmd+,** to open Settings. | Desktop |
| ST-10 | **Help & about:** Send feedback (**done via GitHub Issues**, 2026-11-21: opens `https://github.com/macdipu/OpenReader/issues/new` with a URL-encoded body pre-filled with app version, OS name and version and platform, plus an empty "What happened?" section; never file names, paths or contents; shown on every platform); Rate OpenReader (Android only, opens `https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader` with `url_launcher`; hidden on iOS and desktop, where no store URL is known); Share app (`share_plus`, the shared text includes that Play Store URL on every platform); Show welcome screens again (`setOnboardingComplete(false)`); Reset all settings (`clearSettings()`, with confirmation); version; licenses. | All (Rate Android only) |
| ST-11 | ~~**Cache cap:** automatic limit on the render cache~~ **Removed by the user on 2026-11-21** ("not needed"). | None |
| ST-12 | ~~**History retention:** Forever / 30 days / Off~~ **Removed by the user on 2026-11-21.** | None |
| ST-13 | **"Open files with OpenReader" tip** in place of the default-app card. | Android, iOS |
| ST-14 | **macOS default-app status:** one extra method on the existing `openreader/open_files` channel; File handling as in ST-03. Optional file-access row if the app is sandboxed (needs checking). | macOS |
| ST-15 | Reset the default-app first-run prompt ("ask me again"). | Desktop |

### Phase 3 (Could, only with dependency approval)
| ID | Requirement | Dependency |
|---|---|---|
| ST-16 | Keep the screen awake while reading (BRD §9.18): a "Keep screen awake" switch in Settings > Reading (default off, `AppSettingsRepository.getKeepScreenAwake/setKeepScreenAwake`, removed by both clear methods). The lock is held only while the switch is on, a reader screen is visible (every reader's screen-level `ReaderNightModeView` holds a `ReaderKeepAwake`; a covered route or background workspace tab doesn't tick, so doesn't count) and the app is in the foreground; turning the switch off releases it at once. Failures and unsupported platforms are ignored (`ReaderWakelock`, injectable `WakelockAdapter`). **Built 2026-11-21.** | `wakelock_plus` ^1.8.0 (Q4 approved) |
| ST-17 | Private mode: record no history | none |
| ST-18 | Hide toolbars automatically (immersive reading) | none |
| ST-19 | Hide thumbnails in Recents: a switch in Settings > Privacy (default off, `AppSettingsRepository.getHideThumbnails/setHideThumbnails`, removed by both clear methods); document rows in Recents, Home and History then show the format icon instead of the first-page preview. **Built 2026-11-21.** | none |
| ST-20 | Dynamic colour (Material You): a switch in Settings > Appearance, shown only where the system offers a palette ("Use wallpaper colours" on Android 12+; "Use accent colour" on macOS, Windows and GTK Linux; hidden on iOS, older Android and when no colour is reported). Default off, `AppSettingsRepository.getUseDynamicColor/setUseDynamicColor`, removed by both clear methods; the theme rebuilds live. When on, the palette's primary family replaces the app's accent roles (`secondary*`, plus `primary*` in dark); surfaces, text ink, error and the success tertiary stay the brand's (`AppTheme.light/dark(dynamicScheme)`, `DynamicColorPreferences`). Off or unavailable, the theme is unchanged. Only `DynamicColorPlugin`'s raw palette is used, because `dynamic_color` 2.1 builds `material_ui` ColorSchemes, not the `flutter/material` type the app uses. **Built 2026-11-21.** | `dynamic_color` ^2.1.0 (Q4 approved) |

### Section order
- **Mobile:** Permissions → Reading → Appearance → Data → Privacy → Open with → Help & about.
- **Desktop:** File handling → Reading → Appearance → Data → Privacy → Keyboard shortcuts → Help & about.

## Out of Scope
- App lock with biometrics (`local_auth`): a separate CR.
- Default page fit and zoom (BRD §9.18): readers don't offer it, so it needs Kit API work first (separate Kit CR, see Q5).
- Volume keys turn pages: needs native code; a separate CR.
- Language switch (bn/en): the UI isn't translated yet, so stays hidden (Q6).
- Any change to `universal_document_viewer`.
- Per-format reader options (spreadsheet gridlines, CSV delimiter).

## Expected Behavior After Change
- An Android user without file access sees the status first in Settings and can fix it in one or two taps. Coming back from OS settings updates the status.
- A Windows or Linux user sees which document types already open in OpenReader and can change any of them.
- Reading preferences can be set once in Settings and match what the reader toolbars show.
- The Privacy section states truthfully what leaves the device, and the user can turn telemetry off.
- Desktop Settings reads like a desktop settings window, and Ctrl/Cmd+, opens it.

## Known Affected Areas
- `lib/features/settings/presentation/`: `settings_view.dart` (split into section widgets), `settings_controller.dart`, `settings_binding.dart`, `default_app_dialog.dart`; new desktop two-pane widget.
- `lib/services/utilities/storage_access_service.dart`: a status enum built from existing calls.
- `lib/services/platform_integration/default_app_service.dart`: `queryDefaults()`.
- `lib/core/domain/repositories/app_settings_repository.dart` and `lib/core/data/repositories/app_settings_repository_impl.dart`: restore-position, telemetry, cache-cap and history-retention preferences.
- `lib/app/flavours/app_flavour.dart`: apply the saved telemetry choice at startup.
- `lib/core/presentation/widgets/app_shortcuts.dart`, `lib/app/shell/`: Ctrl/Cmd+,.
- Reader controllers (PDF, text, sheet, Word, slides): restore-position flag; night mode and PDF mode kept in sync.
- `macos/Runner` (ST-14 only): channel method.
- Tests under `test/`.

## Constraints
- AGENTS.md §1–§2: OpenReader only; the Kit is not touched.
- No new dependencies in Phases 1–2. Phase 3 dependencies need explicit approval.
- Keep the existing look (section labels, cards, `_ActionRow` style) unless the desktop two-pane layout replaces it (ST-08).
- Never fabricate status: if a default or permission can't be read, show no status instead of a guess.
- Telemetry changes must not block app start (keep the existing Firebase init guard).
- BRD §9.18 corner cases: cache cleared while a file is open; restore position turned off; theme changed while a reader is active.
- Don't run `dart format` on whole files (the repo isn't formatted).

## Acceptance Criteria
- AC-01 (ST-01): On Android, each access state shows the right label and calls the right action; after returning from OS settings the status updates without a restart.
- AC-02 (ST-02): On iOS, the row opens app settings; no access status is shown.
- AC-03 (ST-03): On Linux and Windows, status per type is parsed from mocked `xdg-mime` / `reg query` output; when it can't be read, the button shows without status; Set and Set all call `makeDefault` with the right types.
- AC-04 (ST-04): A value changed in Settings appears in the reader toolbar, and the reverse, for PDF mode, night mode, font size and line wrap.
- AC-05 (ST-05): With restore off, a document that has a saved position opens at the start; turning it back on restores it.
- AC-06 (ST-06): The Privacy section has no telemetry switches and has a Privacy policy link that opens the policy URL (error snackbar on failure); its text says documents are never uploaded, that crash reports and analytics are always collected and sent to Google Firebase in release builds, and that debug builds send nothing.
- AC-07 (ST-07): Clear history asks for confirmation, then empties Recents/History. (Cache clearing was removed on 2026-11-21.)
- AC-08 (ST-08, ST-09): At 1200px, the two-pane layout shows; arrow keys and Tab work; Ctrl/Cmd+, opens Settings from any shell page.
- AC-09: Widget tests at 360px, 700px and 1200px wide check which sections each platform shows.
- AC-10: The app's `flutter test` passes, and `flutter analyze` shows 0 errors and 0 warnings.
- AC-11: Manual checks on Android, iOS, macOS, Windows and Linux, with gaps recorded in the work item.


Note (user, 2026-11-21): the default PDF mode row was removed from Settings; the PDF reader's toolbar owns that choice.

Note (redesign 2026-11-21): the Settings page was redesigned for length and consistency (Material 3 grouped list). Mobile sections are now File access, Reading, Appearance, Privacy & data, About (desktop: File handling first, then Reading, Appearance, Privacy & data, Shortcuts, About). One row style (plain 24dp icon, title, one supporting line, trailing control), Theme as one 3-segment text control, Text size stepper without a sample sentence, the Allowed file-access row without a supporting line, the Data and Privacy sections merged, the Open-with tip moved under About as a footnote. Behaviour, dialogs, snackbars and the controller are unchanged. Page height at 360x800 (widget-test font): 2355 -> 1613 logical px. See `validation/parity-matrix.md`.

Note (desktop refactor 2026-11-21): macOS, Windows and Linux now use a compact pointer density (`SettingsDensity.compact`, chosen once in `settings_widgets.dart` from `PlatformInfo.isDesktop`, overridable with `SettingsDensityScope`): 40px single-line rows, 52px with a supporting line, bodyMedium titles, bodySmall supporting text, 20px icons, 32px controls (switch without the padded touch target, Theme as a 32px segmented control on the Theme row, 32px stepper buttons). Phones and tablets keep the comfortable density unchanged. File handling is one card with a header row ("Open these files with OpenReader" + Set all, disabled when every type is already the default) and one 40px line per type (name and extension inline, fixed-width status column, fixed-width Set column with an empty space of the same width when already default); the Windows default-apps link and Ask me again are text buttons under the card. Two panes: 220px section list with a lighter selection (surfaceContainerHigh fill, indicator bar, bold), pane content at most 720px and left-aligned, title "Settings" only (subtitle removed), the section heading fixed above the scrolling content (never clipped) and the pane back at the top on every section change. Keyboard: the list takes focus when Settings comes on screen and after a click on an item; Up/Down/Home/End move the selection; Tab goes into the pane. Keyboard shortcuts are a left-aligned table (key cap column, then the description). Key labels (Settings and the sidebar Open file chip) are `KeyCap`s in the UI font, not JetBrains Mono, so O is not read as 0. Behaviour, dialogs, snackbars and the controller are unchanged.

## Open Questions
- Q1: DECIDED 2026-11-21 (user): Firebase crash reporting and analytics are always on; no opt-in, no opt-out, no per-user permission. Disclosure statement only (ST-06).
- Q2: DECIDED 2026-11-21 (user): the policy is approved; Settings > Privacy links `https://macdipu.github.io/OpenReader/privacy.html` on every platform (ST-06).
- Q3: DECIDED 2026-11-21 (user): feedback goes to GitHub Issues (`https://github.com/macdipu/OpenReader/issues/new`, pre-filled body; needs a free GitHub account). No email address.
- Q4: DECIDED 2026-11-21 (user): `wakelock_plus` (ST-16) and `dynamic_color` (ST-20) approved; both built.
- Q5: Default page fit / zoom: keep it as a later Kit CR, or drop it from the BRD?
- Q6: Keep the language switch hidden until the UI is translated?
- Q7: Windows: if the `UserChoice` spike fails, fall back to the button without status? (Recommended: yes.)
- Q8: macOS: is the app sandboxed? If not, should the file-access row be dropped?
