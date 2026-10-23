# CR-OPENREADER-BROWSE: QA (2026-10-23)

## Android emulator (Pixel 4a)
| Check | Result | Evidence |
|---|---|---|
| Home: "Browse files" button, Continue Reading and Recent; no format chips, counts, scan or badges | PASS (revision 0 build) | `qa/b-01-home.png` |
| Browse tab: roots list ("Internal storage"); no "LOCAL"/"OFFLINE" pills | PASS (revision 0 build) | `qa/b-02-browse.png` |
| Browse: Internal storage lists folders first, with breadcrumb, back, filter, format pills and sort | PASS (revision 1 build) | `qa/b-03-internal.png` |

The emulator was shut down during the revision 1 session, after the folder listing was checked. Opening a document from Browse, subfolder search and the review fixes (tab-scoped back, de-duplicated nested roots, search box sync, active root, the global cap, the system-folder skip, symlinks) are verified by tests only.

## Tests
- `flutter test`: 209/209 pass.
- `flutter analyze --no-fatal-infos`: 0 errors, 1 pre-existing warning.
