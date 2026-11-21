# AUDIT-REPORT: permissions and navigation (CR-PERMISSIONS-NAV-AUDIT)

Date: 2026-11-21. Read-only audit by three agents (Android permissions incl. Chinese-ROM addendum; iOS/macOS/Windows/Linux and privacy; navigation). Nothing was changed by the audit. Evidence tags: [REPO] verified in the repo; [OEM] known vendor behaviour, not verified here; [DEVICE] needs a real device. Observed on a real OPPO CPH2269, Android 11, ColorOS, with a debug build of commit 7ac656e.

Owner principle: least privilege; request only what is essential, only when needed, explain the purpose; prefer scoped access and system pickers; handle denial gracefully; comply with Android/iOS policy, privacy and security standards; simplify navigation without changing function or UI/UX; audit first, then only necessary improvements.

## Verdict
- Over-requesting is not the main problem. No unused iOS usage strings, no broad entitlements, no background modes, no automatic permission request (every request follows a tap), READ_MEDIA_* already removed.
- Real gaps: (1) permissions and components added by two unused plugins; (2) the desktop self-updater runs downloaded code with no integrity check; (3) limited mode breaks re-opening files you shared or picked; (4) the in-app disclosure for All files access is thin; (5) iOS is half-wired; (6) the status refresh and wording are weak on vendor ROMs.
- Navigation is already small and consistent: 11 routes, all used, one entry path for opening documents. Only one probable defect.

## Findings (ids from the three audits)

### Android permissions
| ID | Sev | Finding | Fix | Class |
|---|---|---|---|---|
| A-02 | high | `workmanager` and `home_widget` are unused in `lib/` yet add POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE and exported services/receivers. Tied config: `android/app/build.gradle.kts:86-91`, `android/app/proguard-rules.pro:1-4` (WorkManager R8 crash workaround). | Remove both dependencies, the androidx.work lines and the Room keeps together; release build + cold start to verify. | Necessary |
| A-03 | medium | `document_interaction_controller.dart:94-95,144,204,211,221-231`: only `fromOtherApp` skips the access check, so files shared or picked into the app cache cannot be re-opened from Recents/Favorites in limited mode ("no longer has access", wrong "Grant Access"). | Check access only for shared-storage paths, not the app's own cache/files dirs. | Necessary |
| A-06 | medium | Onboarding text (`onboarding_view.dart:52-55`) and Home banner (`home_view.dart` ~379-385) lack "files are never uploaded or shared" and a policy link. Play expects a prominent disclosure. | Text + link only. | Necessary |
| A-07 | low | `READ_EXTERNAL_STORAGE` has `maxSdkVersion="32"`; it does nothing on API 30-32. | `maxSdkVersion="29"`. | Necessary (one line) |
| A-12 OEM | medium | Home, Browse and the Grant-Access snackbars read the permission once after the OS page; on ColorOS the value was stale for one resume. Settings already has a delayed re-check. | Shared re-check window (0, ~1 s, ~3 s) after resume and after the OS page. | Necessary |
| A-13 OEM | medium | `openAllFilesAccessSettings` falls back to app-info only if `request()` throws; a vendor page that opens or nothing opening gives no next step. | After returning without access, offer the how-to and "Open app settings". | Necessary |
| A-14/A-15 OEM | medium/low | Help text and denied messages do not mention the ColorOS three-option page or say to pick "Allow management of all files", not "media only". | Wording + short per-vendor lines. | Necessary |
| A-04 | medium | `MainActivity.kt:171-185` reuses `incoming/<name>`; a different file with the same name shows stale content. | Key the copy by URI hash or size+mtime. | Necessary (data correctness) |
| A-01 | high | MANAGE_EXTERNAL_STORAGE (All files access, Play-restricted) is used by Browse and Search (`folder_browser_service.dart:46-145`). Scoped replacement (SAF tree) is a large rewrite; MediaStore cannot list documents. | **Owner decision**: keep and file the Play Console declaration + demo video, or build optional SAF folder access later, or a limited-mode Play flavour. | Owner decision |
| A-05 | medium | No `allowBackup`/`dataExtractionRules`: Recents DB with dead cache paths is auto-backed-up. | `allowBackup="false"` or extraction rules. | Owner decision |
| A-08 | low | `file://` VIEW filter and `materialize` accept any existing path. | Reject paths under app private dirs, or drop the filter. | Optional |
| A-09 | low | OpenReader offered for plain-text SEND but does nothing. | Remove `text/plain` SEND or handle it. | Optional |
| A-16 OEM | low | API <= 29 on some ROMs reports "denied" not "permanently denied". | Fallback to app settings on second tap. | Optional |
| A-11 | info | Always-on Firebase + AD_ID kept by the owner. | Play Data safety + Advertising ID declaration must say Analytics, not advertising. | Owner task |

### Desktop, iOS, privacy
| ID | Sev | Finding | Fix | Class |
|---|---|---|---|---|
| B-01 | high | `desktop_update_installer.dart:86-125,181,197-238`: downloaded installer is run with no checksum/signature, no HTTPS/host check (`app_update_service.dart:120`); `release.yml` publishes no checksums. | Publish SHA256SUMS in `release.yml`; verify before staging; require https and github.com / objects.githubusercontent.com. | Necessary |
| B-02 | high | macOS updater runs `xattr -dr com.apple.quarantine` (`:224`) on an ad-hoc-signed, unnotarized build. | Remove that line (one Gatekeeper prompt returns). Signing/notarization is the real fix, needs credentials. | Necessary |
| B-08 | medium | Linux updater uses a fixed path in shared `/tmp` (`:89-91,217-237`). | Per-user dir or `createTemp`. | Necessary |
| B-10/B-11 | low | Update scripts interpolate install paths into shell/PowerShell text (`:181-190,219-235`). | Pass paths as arguments / single-quoted strings. | Necessary (same file) |
| B-04 | high (pre-submission) | `ios/Runner/Info.plist:10,18` display name "Onkur Customer". | Set "OpenReader". | Necessary (trivial) |
| B-03 | high (pre-submission) | No `PrivacyInfo.xcprivacy`. | Add manifest: tracking false, required-reason APIs, collected data. | Necessary before iOS submit |
| B-07 | medium | Firebase Analytics linked with ad-ID support on iOS. | `$FirebaseAnalyticsWithoutAdIdSupport = true` in Podfile; no ATT. | Necessary before iOS submit |
| B-05 | medium | No document types, no Share Extension on iOS, though the in-app note promises Files/Share-sheet. | Add document types (macOS plist as template); extension or reword the note. | Before iOS submit |
| B-06 | medium | `ios/Podfile.lock` does not match current plugins. | `pod install`, commit. | Build task, before iOS submit |
| B-12 | medium | `docs/privacy.html` omits iOS though Firebase initialises on iOS. | Add iOS wording when iOS ships; fill the nutrition label. | Before iOS submit |
| B-09 | medium | macOS has no hardened runtime; sandbox off; no MSIX. Store packaging not possible as is. | Hardened runtime for notarization; stores are a product decision. | Optional / decision |
| B-13 | low | `internet_connection_checker_plus` default hosts (third-party) are dormant (no caller sets requiresNetwork). | Remove the dependency and dead branch. | Optional |
| B-14 | low | Same unused plugins linked on iOS. | Covered by A-02. | with A-02 |
| B-15 | low | Linux `.desktop` MimeType lacks `.tsv`/`.xlsm`; `Exec` unquoted. | Add MIME types, quote Exec. | Optional |
| B-16 | low | Inno installer runs `powershell -ExecutionPolicy Bypass` unsigned. | Sign installer. | Optional |

### Navigation
| ID | Sev | Finding | Fix | Class |
|---|---|---|---|---|
| N-01 | medium (probable) | `document_interaction_controller.dart:169` `Get.toNamed` with default `preventDuplicates`: on narrow layouts a second document of the same reader type arriving from outside while a reader is open is silently ignored. | Reproduce first; then replace (offNamed) or allow duplicates. Add a test. | Necessary if reproduced |
| N-03 | medium | `android:enableOnBackInvokedCallback` missing; app uses PopScope in Browse, reader fullscreen, search. | Add the manifest flag; check back gesture on a device. | Necessary (device check) |
| N-02 | medium | No PopScope in the shell: Back on Browse/Favorites exits the app. | Optional back-to-Home. | Owner decision (UX) |
| N-04..N-08 | low | Duplicate `Get.until`, debug `NavigationHistoryObserver` (no consumers), reduced-motion not read, resize with /settings pushed, `changeTab` reload workaround. | — | Optional / leave |

### Leave as is
Route/binding structure; single open path; `Get.arguments` convention; one shell, two layouts; permanent controllers and documented workarounds; default transitions; ask-only-after-tap flow and resume re-check; READ_MEDIA_* removals; WAKE_LOCK, INTERNET, ACCESS_NETWORK_STATE; AD_ID set (owner decision); private `cacheDir/incoming` and filename sanitising; non-exported plugin FileProviders; macOS sandbox off for direct distribution; Windows HKCU per-user install; no ATT prompt; `permission_handler` Android-only.

## Not verifiable from the repo
Play Console declarations (All files access, Advertising ID, Data safety), App Store Connect privacy label, signing credentials, per-ROM timing of the stale `isExternalStorageManager()` value, process kill on the permission page, behaviour of other vendors' ROMs.
