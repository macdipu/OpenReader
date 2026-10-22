# CR-OPENREADER-UX Phase 2: emulator QA (2026-10-22, revisions 4-5)

- **Device:** Android emulator `Pixel_4a`.
- **Build:** debug build of revision 4 (on top of v1.0.4).
- **Screenshots:** in `qa-p2r4/`.

| Check | Result | Evidence |
|---|---|---|
| P2r1 #2: text reader close-save | PASS. Scrolled to L389 and closed 0.3s later (NAV POP 22:13:29); reopened at L389. Before the fix it reopened at the older position. | `p4-01`, `p4-02` |
| UX-22: Word restore | PASS. Closed and reopened (POP/PUSH); it restored to paragraph 41. | `p4-04`, `p4-05` |
| UX-19: per-PDF view mode | PASS. Switched to horizontal on page 4; reopening from Home restored horizontal mode and page 4. | `p4-07`, `p4-11` |
| UX-13 / HOME-RECENTS | PASS. Home updated immediately: `qa-report.pdf` leads Continue Reading ("Just now") with a progress bar at about 4/5. | `p4-10` |
| UX-12: no duplicate recents | PASS. 3 cards, with the 4th and 5th recents as Recent rows. | `p4-10` |
| UX-11/14: Home chips, tune icon | PASS. No chip selected; no tune icon. | `p4-10` |
| UX-09/10: Library | PASS. "See All" opens Library > History; Clear History shows on History only; the PDF row has a progress bar. | `p4-12`, `p4-13` |
| UX-08/15: Files tap, long-press, delete | PASS (revision 1 build). Tap opens the reader; long-press shows the sheet; Delete is red and the confirm dialog is destructive. | `p2-13`, `p2-14` |
| UX-21: jump-to-match | PASS (revision 1 build). L350 lands exactly at the top. | `p2-16` |
| UX-17: no-match empty state | PASS. "No matching documents", with no Scan button. | (observed) |
| UX-16: Settings confirm | Blocked on revision 4, because Settings rendered blank (`p4-16`). **PASS on revision 5:** Settings renders; Clear Recent History is red; the confirm dialog has a red Clear; Cancel kept History (5). | `qa-p2r5/p5-02`, `p5-03`, `p5-04` |
| UX-18: resume re-check | **PASS on revision 5.** With access revoked (Android kills the process on revoke, so this was a cold start), Home showed the access banner and Files showed its no-access state with Grant Access (UX-17). The app was then backgrounded and granted access via appops (same PID 5600, so no restart). On resume, Files reloaded to the full list and Home loaded. | `qa-p2r5/p5-06`…`p5-09` |
| P2r4-qa #1 / #3: Settings layout, Library nav label | **PASS on revision 5.** | `qa-p2r5/p5-02`, `p5-04` |

## Defects found (not Phase 2 regressions; #1 and #3 fixed in revision 5)
1. **Settings screen is blank.**
   - Reproduced in a widget test: "BoxConstraints forces an infinite height" from the `Row(crossAxisAlignment: stretch)` at `settings_view.dart:110` inside the `ListView`.
   - It has been in the code since `64c6da9` (2026-09-20).
   - It wasn't seen on device because `bootstrap`'s `FlutterError.onError` sends errors only to `dart:developer` `log()`, which is not in logcat.
   - The fix is one line: wrap the row in `IntrinsicHeight`.
2. **Word reader clipping (docx_file_viewer paged layout).** At the page break, paragraph 44's text is cut off and paragraphs 45-48 are not shown. This is a library rendering issue.
3. **Navigation label.** The bottom nav still says "Favorites" for the tab titled "Library".
