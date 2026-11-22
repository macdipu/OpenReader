# TECH-SPEC: CR-READER-SELECT-OCR (DRAFT, not frozen, awaiting the technical gate)

Source: `CR.md`, ADR-001, approved plan. Progress goes in `agentic/data/work-items/CR-READER-SELECT-OCR.md`.

## Decisions
- PDF selection: custom model (ADR-001). Real-text formats: `SelectionArea`.
- Kit release 0.3.0 (additive, no new dependency). Publishing needs the owner's explicit approval each time.
- OCR engines and language resolver live in OpenReader; the Kit holds the interface and PDF plumbing only.

## Work packages
- WP-1 (Kit) PDF text layer + selection (SO-01, 03, 04, 05): `lib/src/pdf/{pdf_text_layer,pdf_selection}.dart`, `pdf_view.dart`, `pdf_controller.dart`; tests `pdf_selection_test.dart`, `pdf_view_test.dart`.
- WP-2 (Kit) Word, plain text, slides selection (SO-02): `word_view.dart`, `plain_text_view.dart`, `slides_view.dart`; controller members on `DocumentController`; contract and public API tests.
- WP-3 (Kit) OCR contract and PDF plumbing (SO-11, 12): `lib/ocr.dart`, `lib/src/ocr/*`, `PdfiumDocument.renderPagePng`.
- WP-4 (OpenReader) toolbars and menus (SO-06), then OCR UI (SO-13), engines (SO-14), resolver and settings (SO-15).
- WP-5 (Kit + OpenReader) outline, highlight primitives, bookmarks (SO-07..10), storage is an app database (Q1 decided).
- Linux Tesseract is in the first OCR release (Q2). OCR languages are only those the engine models support (Q3). No image viewer (Q4).

## Order
WP-2 first (smallest, no native risk), then WP-1, WP-3, WP-4, WP-5. Each WP: Kit tests alone, then local integration through `pubspec_overrides.yaml`, publish only after approval.

## Verification
As in the approved plan section 7.
