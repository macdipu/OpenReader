# Workspace: several documents at once (tabs and side by side)

Status: built on Windows (tabs, side by side, same document twice, pane close, single window), 2026-10-30. Open items are in docs/TODO.md.

## Goal

On wide windows (desktop, large tablets, an unfolded Fold) a user can have several documents open at the same time,
switch between them as tabs, and read two next to each other. Phones and narrow windows keep today's behaviour: one
reader per screen, pushed on top of the list.

## What exists

- A reader is a pushed route (`AppRoutes.pdfReader` ...). `DocumentInteractionController.openDocument` is the single
  entry point; Home, Browse, Library, Search, drag and drop, launch arguments, "Open file" and Android intents all go
  through it (and through `IncomingIntentService`).
- Each reader controller already takes its `DocumentModel` in the constructor. They are registered by bindings from
  `Get.arguments`, one instance per type, which is why two PDFs cannot be open today.
- Reader views are `GetView<XController>`; they only ever reach their own controller through `controller`.
- The controllers leave with `Get.back()` (Esc, a cancelled password, error "Close" buttons).

## Design

### State: `WorkspaceController` (permanent)
- `tabs`: ordered list of `WorkspaceTab(id, document)`.
- `focusedPane` (0 or 1), `paneTabs[2]` (which tab each pane shows; pane 1 only while split), `split` flag and
  `ratio` (left pane's share, 0.25 to 0.75).
- `visible`: whether the workspace or a list page (Home, Browse, Library) fills the content area.
- `enabled`: set by the shell from the window size; when false everything falls back to routes.
- Opening a document that is already open focuses its tab. Closing the last tab hides the workspace.

### One controller per tab, kept alive
- A tab's reader controller is created with `Get.put(controller, tag: tab.id)` the first time it is shown, and
  deleted with the tab. The view gets the tag (`GetView.tag`), so nothing else about the readers changes.
- Every tab's view stays mounted (positioned off screen when hidden) so scroll position, zoom, search and the PDF
  engine survive switching. Cost: memory per open document. Mitigation: a cap on open tabs (12), asking to close one.
- Controllers get an `exitHandler` and an `embedded` flag (in the shared `ReaderFullscreen` mixin): inside a tab, "close"
  buttons close the tab and Esc only leaves full screen or closes search; it never closes the document.

### UI
- **Tab strip** above the content: type-coloured icon, name, close button, drag to reorder (`ReorderableListView`),
  middle-click to close, context menu (Close, Close others, Open in left/right pane). A "Side by side" toggle and a
  "+" that returns to Home sit at the right.
- **Panes:** one pane normally; with split, two panes with a draggable divider. A click anywhere in a pane focuses it;
  clicking a tab puts that document in the focused pane (and swaps if it was in the other one).
- **Sidebar:** an "Open documents (n)" entry appears while tabs exist, so Home and the workspace are one click apart.
- **Keyboard:** Ctrl+W close tab, Ctrl+Tab / Ctrl+Shift+Tab next/previous, Ctrl+\ toggle split.
- Split needs at least 900 px of width; below that it is off and the toggle is hidden.

### Opening
- `openDocument(...)`: `workspace.enabled` ? `workspace.open(document)` : the existing route. A pushed Search page is
  popped first so the workspace is what the user sees.
- History is already recorded at open (`_recordOpen`), so tabs get it for free.

### Windows: open in the running window
- Today a second launch (double-click, Open with) starts another process and window. With tabs it should add a tab to
  the window that is already running: the runner keeps a named mutex, and a second instance forwards its file
  arguments to the first (`WM_COPYDATA`), which hands them to Dart on the `openreader/open_files` channel, the same one
  macOS uses. Linux (a unique `GApplication`) and the macOS Apple Event path are left alone.

## Out of scope for now
- Restoring open tabs after a restart.
- Dragging a tab out into its own window, or more than two panes.
- Tabs on phones.

## Test plan
- Unit tests for `WorkspaceController`: open, focus existing, close and neighbour selection, reorder, split rules,
  pane assignment, tab cap.
- Widget test: tab strip renders tabs, close and focus work.
- Live on Windows: open 3 documents of different types, switch, split, resize the divider, close, Esc and Ctrl+W
  behaviour, two windows forwarding a file.

## What changed from the plan while building

- **Same document in both panes** (like an editor's "Split right"): a second tab for the same file with its own reader,
  scroll and zoom, titled "name (2)". Splitting with one document open does this automatically. Opening the file
  again focuses the original instead of adding a third view.
- **Pane header with an (x)**: each side has a strip with the tab's name and a close button. Closing a side leaves side by
  side; the document stays a tab, except a copy, which is closed.
- **Shortcuts live in the shell**, not the workspace view: focus can sit in the Home page after switching away, and
  keys only bubble through the focused widget's ancestors.
- A bug found on the way: `embed(Get.put(...))` made Dart infer the controller's type from `embed`'s parameter and
  register every reader as a `ReaderFullscreen`; the readers then could not find their controller.
