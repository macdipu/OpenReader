# ADR-001: PDF text selection uses a custom selection model, not Flutter's `Selectable`

Status: proposed (Phase 0 spike, 2026-11-22). Needs the technical gate before code.

## Context
`PdfView` draws bitmaps inside `InteractiveViewer.builder` and builds only the pages near the viewport. PDFium already gives per-character boxes (`PdfiumDocument.text(page)`). Two ways to select:
- A) custom selection model: own hit-testing, painting, handles, menu (as `SpreadsheetView` does).
- B) a custom `Selectable` per page registered with `SelectionArea`/`SelectionContainer`.

## Spike findings (Flutter 3.50.0 source, read-only)
- `InteractiveViewer` has `panEnabled` but no per-pointer-kind switch (`interactive_viewer.dart:83,681`), so a mouse drag pans. Under B, `SelectableRegion`'s drag selection would compete with that pan. PDF already turns pinch off on mouse platforms; drag-pan needs the same treatment either way.
- `SelectableRegion` edge auto-scroll (`selectable_region.dart:1111-1203`) is driven through `Scrollable` ancestors. `InteractiveViewer` is not one, so dragging a selection past the viewport edge would not scroll.
- A `Selectable` must implement word, paragraph, select-all, clear and edge-update events (`selectable_region.dart:2256-2300`), including geometry for handles, for each page painter. That is most of option A's work, plus the framework contract.
- Pages are unmounted as they scroll away, so a selection spanning pages needs a model outside the widgets anyway (B would lose it, A keeps it in the controller).

## Decision
Option A. A `PdfSelection` model lives on `PdfController` (page + char range, survives unmounted pages). `_PagePainter` paints it like search matches. Mouse drag selects (view pans with wheel/trackpad/Ctrl-wheel there); touch long-press arms selection with handles. Menu/toolbar uses Flutter's `AdaptiveTextSelectionToolbar` so it looks native; extra app actions come through `extraSelectionActions`. Edge auto-scroll is driven by the view's own `TransformationController`.

## Consequences
- More Kit code than B's happy path, but no framework gaps (autoscroll, cross-page persistence, gesture arbitration all under our control).
- Handles and toolbar are rendered by us, so they must be checked per platform (Android, macOS, Windows, Linux) at QA.
- Word, plain text and slides keep the framework's `SelectionArea` (real text), so the two models coexist behind the same controller API (`copySelection`, `selectedText`).
- Revisit if Flutter adds `Scrollable`-free autoscroll for `SelectableRegion`.
