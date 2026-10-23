# CR-OPENREADER-BROWSE: technical spec

Status: APPROVED and COMPLETED (2026-10-23). Released as v1.0.7+9, including revision 1 review fixes.

## Design
- **`FolderBrowserService`** (replaces `FileScannerService`, keeping its volume discovery and format filter):
  - `roots()`: Android gives `/storage/emulated/0` ("Internal storage") plus the other `/storage/*` volumes; desktop gives Home, Documents, Downloads and Desktop, if present.
  - `list(path)`: folders and supported documents directly in `path`. Hidden entries (dot-names) and empty files are skipped. Errors come back as an empty listing with `denied: true`.
  - `search(root, query)`: a stream of matching documents in `root` and below, by case-insensitive name match. It skips hidden folders, stops at a result cap (500), and can be cancelled.
- **Browse tab** (`BrowseController` and `BrowseView`; the old Files tab is removed):
  - **Navigation:** a roots list, then folders. Breadcrumb; back goes up a folder before leaving the tab.
  - **Current folder:** sort (name, newest, largest) and format chips apply to it.
  - **Filter and search:** a filter field narrows the current folder instantly. "Search subfolders" runs `search` with progress and Cancel.
  - **Rows:** `DocumentListTile` with the existing ⋮, long-press sheet and right-click menus. A Grant Access state appears when Android access is missing.
  - **Opening and starring:** both go through `DocumentInteractionController.openFromBrowse` / `toggleFavoriteFor`, which index the document first (`indexDocument`), so recents and favorites foreign keys hold.
- **Home:**
  - Removed: the auto-scan, `refresh`/rescan, the scan banner and counters, the category chips and the "files indexed" line.
  - Pull-to-refresh reloads recents.
  - The empty state and a "Browse files" button go to the Browse tab.
- **Search screen:** unchanged instant search over indexed (opened) documents. A "Search on device" button switches to Browse and runs the subfolder search for the query from the current folder (or every root).
- **Settings:** the Rescan button and the indexed-documents stat are removed; the cache card stays.
- **Shell:** the nav rail's Rescan is removed. The tab is labelled "Browse". `openFiles(category)` is replaced by `openBrowse()`.
- **Onboarding:** there's no first scan. The Android text explains All Files Access is used to browse any folder.
- **Repository:** `rescan` and the scanner dependency are removed.
- **DB v3:** on upgrade, documents rows referenced by neither recents nor favorites are deleted.

## Tests
- Folder service on a temp tree: listing, hidden/empty files skipped, search with cap and cancel, roots.
- Browse controller and view: navigate in and up, filter, sort, open/favorite indexing, Grant Access.
- Home without counts or scan.
- Search screen's "Search on device" hand-off.
- DB v3 cleanup.
- Removal of scan-dependent tests.

## Revision 1 (2026-10-23): review fixes
These fix `validation/review.md`. Approved in-session together with release 1.0.7.
- **Back.** Browse's back handling applies only while the Browse tab is showing.
- **Duplicates.** Search across all storage skips roots nested in another root, and results are de-duplicated by path.
- **Search field.** The field's text follows `filter`: it's cleared on a folder change, and the results view keeps the folder's filter.
- **"Search on device"** pops the Search route with `Navigator.pop`.
- **Search future.** `searchSubfolders` completes on cancel.
- **Search scope and cap.** Search skips heavy system folders (macOS `~/Library`, Windows `AppData`, Android `Android/data` and `Android/obb`). The 500 cap applies to the whole search.
- **Active root.** Back and the breadcrumb follow the root the user opened.
- **Symlinks** to folders and files are listed and searched; each target is resolved once.
- **Index failure.** A failed write in `openFromBrowse` is reported, and the document still opens.
- **Copy.** File Information (desktop) reads "Read from your folders"; stale comments are updated.
