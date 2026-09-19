# OpenReader — Business Requirements Document (BRD)

**Document Version:** 1.0  
**Product Name:** OpenReader  
**Product Type:** Fully Offline Mobile Document Reader  
**Primary Platform:** Android  
**Planned Framework:** Flutter  
**Product Scope:** Reader-only  
**Supported Core Formats:** PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, TXT, CSV  
**Connectivity Model:** Fully offline; no server dependency for document reading  

---

# 1. Executive Summary

OpenReader is a privacy-first, fully offline mobile application that allows users to discover, open, read, search, and navigate common document formats stored locally on their device.

The application is intentionally focused on **reading only**. It will not edit documents, upload documents to cloud services, require user accounts, or depend on a backend for rendering.

The core user promise is:

> **OpenReader lets users read their documents privately, locally, and offline.**

The product should feel fast, simple, reliable, and consistent across file formats while preserving each format's natural viewing model:

- PDF → page-based reader
- DOC/DOCX → paginated or flow-based document reader
- XLS/XLSX/CSV → spreadsheet grid viewer
- PPT/PPTX → slide viewer
- TXT → lightweight text reader

---

# 2. Business Goals

## 2.1 Primary Goals

1. Provide one application for reading major document formats.
2. Operate fully offline after installation.
3. Keep user documents on-device.
4. Make document discovery fast and intuitive.
5. Preserve reading progress across sessions.
6. Support large files without excessive memory usage.
7. Provide reliable handling for corrupted, unsupported, locked, moved, or deleted files.
8. Avoid unnecessary complexity associated with editing, cloud sync, collaboration, or accounts.

## 2.2 Secondary Goals

1. Build a modular architecture that allows new document formats later.
2. Keep the product suitable for low-end and mid-range Android devices.
3. Allow the app to be registered as an OS-level document opener.
4. Create a privacy-focused positioning that differentiates OpenReader from cloud-centric readers.

---

# 3. Non-Goals / Out of Scope

The following are outside OpenReader v1.0 scope:

- Document editing
- PDF annotation
- PDF signing
- Form editing or form submission
- Spreadsheet cell editing
- PowerPoint editing
- Word document editing
- Document creation
- User accounts
- Login or registration
- Cloud synchronization
- Google Drive integration
- Dropbox integration
- OneDrive integration
- AI summarization
- AI chat
- Online OCR
- Online file conversion
- Team collaboration
- Comments/reviews
- Version history
- Remote backup
- Remote analytics containing document names/content

---

# 4. Target Users

## 4.1 Primary User

A user who frequently receives or stores documents on their phone and needs a single offline application to read them.

Typical needs:

- Read downloaded PDFs
- Open Word files received from messaging apps
- View Excel reports
- View PowerPoint presentations
- Read text files
- Reopen recently viewed documents
- Search within documents
- Use the app without mobile data or Wi-Fi

## 4.2 Example User Profiles

### Student
Needs to read notes, presentations, assignments, and PDFs offline.

### Teacher
Needs to review Word documents, PDF lesson materials, spreadsheets, and PowerPoint files without editing them.

### Office Worker
Needs to open reports and attachments from local storage quickly.

### Field Worker
Needs access to documents where internet connectivity is weak or unavailable.

---

# 5. Supported Formats

| Priority | Category | Extensions | v1.0 Requirement |
|---|---|---|---|
| P0 | PDF | `.pdf` | Required |
| P0 | Word | `.docx` | Required |
| P0 | Word Legacy | `.doc` | Required if rendering engine supports acceptable fidelity |
| P0 | Excel | `.xlsx` | Required |
| P0 | Excel Legacy | `.xls` | Required if rendering engine supports acceptable fidelity |
| P0 | PowerPoint | `.pptx` | Required |
| P0 | PowerPoint Legacy | `.ppt` | Required if rendering engine supports acceptable fidelity |
| P0 | Text | `.txt` | Required |
| P1 | CSV | `.csv` | Recommended |
| P2 | Rich Text | `.rtf` | Optional |
| P2 | OpenDocument Text | `.odt` | Future |
| P2 | OpenDocument Spreadsheet | `.ods` | Future |
| P2 | OpenDocument Presentation | `.odp` | Future |

---

# 6. Product Principles

## 6.1 Fully Offline

All document discovery, metadata extraction, rendering, navigation, search, caching, recent history, favorites, and reading progress must work without internet access.

## 6.2 Reader Only

Users can open and read files, but OpenReader must not modify original document contents.

## 6.3 Non-Destructive

Operations performed by OpenReader should never alter the original document unless a future explicitly scoped feature requires it.

## 6.4 Privacy First

Document contents, filenames, paths, reading history, and search terms should remain on-device.

## 6.5 Format-Appropriate UX

Each file type should use a viewer suited to its document model instead of forcing every format into a generic viewer.

---

# 7. Functional Feature List

## 7.1 Local Document Discovery

### Features

- Scan supported documents from user-accessible storage
- Detect supported file extensions
- Categorize files automatically
- Incremental rescan
- Manual refresh
- Avoid duplicate file entries
- Ignore unsupported files from document lists
- Preserve file identity where possible when metadata refresh occurs

### Acceptance Criteria

- User can see supported documents after granting access.
- App does not require internet to scan files.
- Newly added supported files appear after refresh/rescan.
- Duplicate scan operations do not create duplicate entries.

---

## 7.2 File Search

### Features

- Search by filename
- Case-insensitive search
- Partial matching
- Search across supported document categories
- Search within current folder when appropriate
- Empty-state handling
- Clear search action

### Example

Input: `invoice`

Possible results:

- `Invoice_January.pdf`
- `invoice_final.docx`
- `Client Invoice.xlsx`

---

## 7.3 File Sorting

Supported sort modes:

- Name A–Z
- Name Z–A
- Newest modified first
- Oldest modified first
- Largest file first
- Smallest file first
- File type

---

## 7.4 File Filtering

Supported categories:

- All
- PDF
- Word
- Excel
- PowerPoint
- Text
- CSV

---

## 7.5 Recent Files

### Features

- Automatically add file after successful open
- Store last-opened timestamp
- Store last reading position
- Remove individual item from Recents
- Clear all recent history
- File remains on device when removed from Recents

### Corner Case

If a recent file no longer exists, show a missing-file state and allow user to remove the stale history entry.

---

## 7.6 Favorites

### Features

- Add document to Favorites
- Remove document from Favorites
- Open document from Favorites
- Favorite state visible from lists and reader
- Store favorite state locally

### Corner Case

If favorite file is moved/deleted, show unavailable state without crashing.

---

## 7.7 Open From Other Apps

OpenReader should support Android intent-based file opening.

Examples:

- File Manager → Open with OpenReader
- WhatsApp download → Open with OpenReader
- Email attachment downloaded locally → Open with OpenReader
- Browser download → Open with OpenReader

### Required Behavior

1. App receives file URI.
2. Validate file extension/type.
3. Validate readable permission.
4. Open correct reader.
5. Add to Recent after successful load.

---

# 8. Screen Inventory

The v1.0 application should contain the following main screens:

1. Splash / App Initialization
2. Permission / Storage Access Onboarding
3. Home
4. All Files
5. Category Files
6. Folder Browser
7. Search Results
8. Favorites
9. Recent Files
10. PDF Reader
11. Word Reader
12. Excel Reader
13. PowerPoint Reader
14. Text Reader
15. CSV Reader
16. File Information
17. Reader Search
18. Settings
19. About / Privacy
20. Error / Unsupported File States
21. Password-Protected PDF Dialog

---

# 9. Screen-by-Screen Requirements

# 9.1 Splash / Initialization Screen

## Purpose

Initialize local services before showing the main interface.

## UI Elements

- OpenReader logo
- App name
- Minimal loading indicator if initialization exceeds visual threshold

## System Actions

- Initialize local database
- Load theme preference
- Load recent/favorite metadata
- Validate cache
- Check whether onboarding/storage access has been completed

## Navigation

- First launch → Permission / Onboarding
- Returning user → Home

## Scenarios

### Scenario A — First Launch

1. User opens OpenReader.
2. App initializes local database.
3. App detects storage access not configured.
4. App navigates to permission onboarding.

### Scenario B — Returning User

1. User opens OpenReader.
2. Stored preferences load.
3. App navigates to Home.

## Corner Cases

- Local database migration fails
- Corrupted local settings
- Insufficient storage for cache/database
- App process killed during initialization

## Expected Handling

- Recover with safe defaults when possible.
- Never block permanently on splash.
- If local database is corrupted, rebuild non-critical index while preserving original files.

---

# 9.2 Storage Access / Onboarding Screen

## Purpose

Explain why OpenReader needs file access and guide users through Android storage permission flow.

## UI Elements

- Illustration/icon
- Heading: `Access your documents`
- Explanation
- Supported file types
- Primary button: `Allow Access`
- Secondary button: `Not Now`

## Functional Requirements

- Request only required storage/document access.
- Handle Android version differences.
- Show clear explanation before OS permission dialog.
- Support retry if access denied.

## Scenario A — Permission Granted

1. User taps `Allow Access`.
2. Android permission/document picker opens.
3. User grants access.
4. OpenReader scans supported files.
5. Navigate to Home.

## Scenario B — Permission Denied

1. User taps `Allow Access`.
2. User denies permission.
3. App remains usable in limited mode.
4. Show `Choose File` / `Grant Access` option.

## Scenario C — Permanently Denied

1. User previously selected `Don't ask again`.
2. App detects permission unavailable.
3. Show instructions with `Open Settings` action.

## Corner Cases

- User grants only partial folder access
- User revokes permission from OS settings later
- External SD card removed
- Android URI permission expires or becomes invalid

---

# 9.3 Home Screen

## Purpose

Provide fast access to documents and major categories.

## UI Sections

1. App Bar
   - OpenReader title/logo
   - Search button
   - Optional overflow menu

2. Search Field
   - Placeholder: `Search documents`

3. File Categories
   - PDF
   - Word
   - Excel
   - PowerPoint
   - Text
   - CSV

4. Continue Reading
   - Last few documents with reading progress

5. Recent Documents
   - Most recent files

6. Bottom Navigation
   - Home
   - Files
   - Favorites
   - Settings

## Functional Requirements

- Category count may be displayed.
- Tapping category opens filtered file list.
- Tapping recent file opens reader.
- Tapping search activates file search.
- Pull-to-refresh may trigger metadata refresh.

## Empty State

If no documents exist:

- Message: `No documents found`
- Action: `Browse Files`
- Action: `Refresh`

## Scenario A — Normal Home

User has 40 files; home shows category cards and recent files.

## Scenario B — No Storage Access

Home shows permission banner instead of document list.

## Scenario C — No Supported Files

Show friendly empty state without error language.

## Corner Cases

- Recent item points to deleted file
- Thousands of files
- Very long filenames
- Filename contains Unicode/emoji
- File extension uppercase, e.g. `.PDF`

---

# 9.4 All Files Screen

## Purpose

Display all supported documents available to OpenReader.

## UI Elements

- Screen title
- Search icon
- Filter button
- Sort button
- List/grid toggle
- File list

## File Row Information

- File icon
- Filename
- File type
- File size
- Modified date
- Favorite icon if applicable
- Overflow menu

## Overflow Actions

- Open
- Add/Remove Favorite
- Share
- File Information
- Open With
- Remove from Recent, if relevant

## Not Included

- Delete
- Rename
- Move
- Edit

## Corner Cases

- File permission lost
- File size unavailable
- File metadata cannot be read
- Duplicate filenames in different folders
- Unsupported internal content despite valid extension

---

# 9.5 Category Files Screen

## Purpose

Show documents filtered by file type.

Examples:

- PDF Files
- Word Files
- Excel Files
- PowerPoint Files

## Features

- Search within category
- Sort
- List/grid mode
- Open file
- Favorite
- Share
- File information

## Corner Cases

- Category becomes empty after files removed externally
- Unsupported legacy files displayed accidentally
- File parser reports invalid format

---

# 9.6 Folder Browser Screen

## Purpose

Allow manual navigation of accessible folders.

## UI Elements

- Breadcrumb/path
- Folder list
- Supported file list
- Back/up navigation
- Search current folder

## Features

- Enter folder
- Go to parent folder
- Open supported file
- Hide unsupported files by default
- Optional toggle to show all files

## Corner Cases

- Circular/symbolic path references where applicable
- Folder inaccessible after permission change
- Empty folder
- Very deep folder structure
- SD card unexpectedly removed

---

# 9.7 File Search Screen

## Purpose

Search local indexed documents by filename.

## UI Elements

- Search input
- Clear icon
- Result count
- Search results
- Recent search terms optional

## Search Rules

- Case-insensitive
- Partial match
- Trim extra spaces
- Unicode-safe
- Extension can be included in search

## Example Scenario

Search: `report`

Results:

- `Annual_Report_2026.pdf`
- `report-final.docx`
- `Monthly Report.xlsx`

## Corner Cases

- Blank search
- Search only punctuation
- 10,000+ indexed files
- File removed during search

---

# 9.8 Favorites Screen

## Purpose

Show locally favorited documents.

## Features

- Open file
- Remove favorite
- Search favorites
- Sort favorites

## Empty State

`No favorite documents yet.`

## Corner Cases

- Favorite file missing
- File moved
- Permission revoked

---

# 9.9 Recent Files Screen

## Purpose

Show reading history ordered by latest opened date.

## Features

- Open
- Remove single history item
- Clear all history
- Search recent files
- Show last opened time
- Optionally show reading progress

## Confirmation

`Clear all recent files? This will not delete your documents.`

---

# 9.10 PDF Reader Screen

## Purpose

Provide high-quality offline PDF reading.

## Core Features

- Offline rendering
- Single-page mode
- Continuous vertical mode
- Horizontal page mode
- Pinch-to-zoom
- Double-tap zoom
- Fit width
- Fit page
- Current page indicator
- Jump to page
- Page thumbnails
- Text search
- Search result highlighting
- Previous/next result
- Table of contents/bookmarks if embedded
- Internal hyperlinks
- External hyperlink handoff
- Password-protected PDF support
- Full-screen mode
- Portrait/landscape support
- Remember page and zoom where practical

## Reader App Bar

- Back
- Filename
- Search
- Favorite toggle
- Overflow menu

## Bottom Controls

Potential controls:

- Page number
- Thumbnail toggle
- Jump slider
- View mode

## Scenario A — Standard PDF

1. User taps PDF.
2. Reader opens first or remembered page.
3. User scrolls to page 18.
4. User leaves app.
5. App stores page 18.
6. Reopening resumes page 18.

## Scenario B — Search PDF

1. User taps search.
2. Searches `revenue`.
3. App shows result count.
4. Matching text is highlighted.
5. Next/previous controls navigate results.

## Scenario C — Password PDF

1. PDF is encrypted.
2. App shows password dialog.
3. Correct password opens file.
4. Incorrect password shows error.

## Corner Cases

- Corrupted PDF
- Huge image-only PDF
- Missing fonts
- Embedded malformed image
- Encrypted PDF with unsupported encryption
- Empty PDF
- PDF with 5,000+ pages
- Rotated pages
- Mixed page sizes
- Hyperlink points to missing page
- Search unavailable because PDF contains scanned images only

---

# 9.11 Word Reader Screen

## Purpose

Render DOC/DOCX content for reading without editing.

## Core Features

- Text rendering
- Paragraphs
- Headings
- Font styles
- Bold/italic/underline
- Lists
- Tables
- Images
- Page breaks
- Headers and footers where supported
- Hyperlinks
- Search text
- Zoom/font scale depending renderer
- Portrait/landscape
- Full screen
- Remember reading position

## Search

- Search string
- Highlight matching text
- Next/previous match

## Scenario A — Simple DOCX

Text, images, and tables load successfully.

## Scenario B — Complex Layout

Document includes floating images, text boxes, section breaks, and unusual fonts.

Expected behavior:

- Preserve readable content.
- Gracefully simplify unsupported layout elements.
- Never silently alter original file.

## Corner Cases

- Unsupported fonts
- Missing linked image
- Embedded object
- Macros
- Corrupted DOCX ZIP structure
- Very large table
- Right-to-left text
- Mixed-language document
- Legacy `.doc` incompatibility
- Password-protected Office file

---

# 9.12 Excel Reader Screen

## Purpose

Provide read-only spreadsheet viewing.

## Core Features

- Workbook opening
- Sheet tabs
- Cell values
- Formula result display
- Text
- Dates
- Numbers
- Percentage/currency formatting
- Font formatting where supported
- Cell background
- Borders
- Merged cells
- Row height
- Column width
- Horizontal scrolling
- Vertical scrolling
- Pinch zoom where possible
- Frozen rows/columns where supported
- Search cells
- Jump to matching cell
- Remember active sheet and scroll position

## Scenario A — Multi-Sheet Workbook

1. User opens workbook.
2. Sheet `Summary` selected.
3. User switches to `April`.
4. Scrolls to cell H45.
5. Leaves app.
6. Reopens and resumes April/H45 region.

## Scenario B — Formula Workbook

Cell contains formula `=SUM(B2:B10)`.

Expected:

- Display stored/calculated result if available.
- Do not recalculate complex workbook unless selected engine supports it.

## Corner Cases

- Workbook has 100+ sheets
- Sheet contains 100,000+ rows
- Hidden sheets
- Protected workbook
- Unsupported external formula references
- Charts not supported
- Macros/VBA
- Merged-cell-heavy layout
- Invalid formula cache
- Extremely wide sheet
- Empty workbook

---

# 9.13 PowerPoint Reader Screen

## Purpose

Display slides offline in a read-only presentation viewer.

## Core Features

- Slide rendering
- Swipe next/previous
- Thumbnail strip
- Jump to slide
- Slide number
- Full-screen mode
- Landscape presentation mode
- Zoom
- Search slide text
- Text rendering
- Images
- Shapes
- Tables
- Backgrounds/themes
- Charts where supported
- Remember last slide

## Not Required

- PowerPoint editing
- Slideshow animations
- Complex transitions
- Presenter notes editing
- Embedded macros

## Scenario A — Standard PPTX

Slides open and user swipes through slides.

## Scenario B — Complex Slide

Slide contains SmartArt, embedded chart, non-standard font, and video.

Expected:

- Render supported objects.
- Show fallback/placeholder for unsupported embedded media.
- Do not crash.

## Corner Cases

- Missing fonts
- Embedded video/audio
- Linked external assets
- Unsupported SmartArt
- Corrupted presentation
- Password-protected presentation
- 500+ slides
- Very large slide images

---

# 9.14 Text Reader Screen

## Purpose

Provide lightweight TXT viewing.

## Features

- Plain text display
- Search
- Adjustable text size
- Line wrap toggle
- Full screen
- Remember scroll position
- Encoding detection where feasible

## Corner Cases

- Very large text file
- Unknown encoding
- Binary file renamed as `.txt`
- Extremely long line without breaks
- RTL text

---

# 9.15 CSV Reader Screen

## Purpose

Display CSV data as a read-only grid.

## Features

- Row/column grid
- Header detection
- Horizontal scrolling
- Vertical scrolling
- Search values
- Zoom/density control
- Delimiter detection if feasible
- Remember position

## Corner Cases

- Comma delimiter
- Semicolon delimiter
- Tab-separated data incorrectly named `.csv`
- Quoted commas
- Multi-line quoted values
- Different encodings
- 1M+ rows
- Uneven row lengths
- Empty rows

---

# 9.16 File Information Screen

## Fields

- Filename
- File type
- File size
- File path/URI representation
- Modified date
- Created date if available
- Page count for PDF
- Sheet count for spreadsheet
- Slide count for presentation
- Author/metadata if available

## Actions

- Share
- Open With
- Favorite toggle

## Corner Cases

- Metadata unavailable
- Path unavailable due to scoped storage
- File deleted after info screen opened

---

# 9.17 Reader Search UI

## Purpose

Provide text search inside supported file types.

## UI

- Search input
- Result counter, e.g. `3 of 18`
- Previous result
- Next result
- Close

## Behavior

- Search is local.
- Search should not freeze UI.
- Long searches should be cancellable.
- Results should be highlighted when renderer permits.

## Unsupported Case

For scanned-image PDFs with no text layer:

`No searchable text found in this document.`

Because OCR is outside v1.0 scope.

---

# 9.18 Settings Screen

## Sections

### Appearance

- Theme: System / Light / Dark

### Reader

- Default PDF scroll direction
- Keep screen awake while reading
- Restore last reading position
- Default page fit mode

### Files

- Refresh file index
- Clear Recent history
- Clear cache

### Privacy

- Explain local-only processing

### About

- Version
- Privacy Policy
- Open-source licenses

## Corner Cases

- Cache clear while file is open
- User disables restore position
- Theme changes while reader active

---

# 10. Cross-Format Reader Requirements

All reader types should support the following where technically applicable:

- Back navigation
- Filename display
- Favorite toggle
- Share original file
- File information
- Open With
- Full-screen mode
- Rotation support
- Reading position persistence
- Error recovery

---

# 11. User Scenarios

# Scenario 1 — First-Time User Reads a PDF

## Preconditions

- OpenReader freshly installed
- User has PDFs on device

## Flow

1. User launches OpenReader.
2. App explains document access.
3. User grants permission.
4. App scans files.
5. Home displays PDF category.
6. User taps PDF.
7. User selects `Class Notes.pdf`.
8. Reader opens file.
9. User reads to page 42.
10. User closes app.
11. User reopens OpenReader later.
12. `Class Notes.pdf` appears in Continue Reading.
13. File resumes at page 42.

## Success Criteria

- No internet required.
- Original PDF unchanged.
- Reading position restored.

---

# Scenario 2 — User Opens a DOCX From WhatsApp

## Flow

1. User downloads DOCX through WhatsApp.
2. Android presents Open With options.
3. User chooses OpenReader.
4. OpenReader receives content URI.
5. App verifies readable access.
6. Word viewer opens document.
7. File is added to Recents.

## Corner Cases

- URI permission is temporary.
- File deleted from WhatsApp later.
- Document contains unsupported layout elements.

---

# Scenario 3 — User Searches for a Local File

1. User opens Home.
2. Taps search.
3. Types `salary`.
4. App searches indexed filenames.
5. Results show PDF and XLSX matches.
6. User taps spreadsheet.
7. Excel Reader opens workbook.

---

# Scenario 4 — User Reads Spreadsheet Offline

1. User opens `Budget.xlsx`.
2. Workbook loads locally.
3. User selects `March` sheet.
4. Scrolls horizontally to column K.
5. Scrolls vertically to row 120.
6. App saves state.
7. User exits.
8. Reopen restores same sheet and approximate location.

---

# Scenario 5 — File Is Deleted Externally

1. User opens OpenReader.
2. `Report.pdf` appears in Recent.
3. File was deleted using another file manager.
4. User taps `Report.pdf`.
5. OpenReader detects file missing.
6. Show:
   `File not found. It may have been moved or deleted.`
7. Provide `Remove from Recents` action.

---

# Scenario 6 — Storage Permission Revoked

1. User previously granted folder access.
2. User revokes access through Android Settings.
3. User opens OpenReader.
4. Indexed entries may still appear.
5. Attempting to open file fails permission check.
6. App displays reauthorization guidance.

---

# Scenario 7 — User Opens Corrupted PPTX

1. User selects presentation.
2. Parser fails.
3. App shows:
   `Unable to open this presentation. The file may be damaged or incomplete.`
4. App does not crash.
5. User can return to previous screen.

---

# Scenario 8 — Password-Protected PDF

1. User selects locked PDF.
2. App requests password.
3. User enters wrong password.
4. Inline error appears.
5. User enters correct password.
6. Document opens.

---

# Scenario 9 — Huge PDF

1. User opens 600 MB PDF.
2. App loads document metadata first.
3. Viewer renders current pages lazily.
4. Nearby pages are preloaded selectively.
5. Memory usage remains bounded.
6. User can cancel/return if loading is too slow.

---

# Scenario 10 — Airplane Mode

1. User enables airplane mode.
2. Opens OpenReader.
3. Browses files.
4. Opens PDF, DOCX, XLSX, PPTX.
5. Searches inside supported documents.
6. Favorites and Recent work normally.

## Success Criteria

All core reader functions remain operational.

---

# 12. Detailed Corner Cases

## 12.1 Storage & File System

- User denies access
- User grants access to only one folder
- Permission revoked later
- File renamed externally
- File moved externally
- File deleted externally
- SD card removed
- SD card reinserted with changed mount URI
- Duplicate copies of same filename
- File path contains Unicode
- File path contains symbols
- Read permission exists but metadata access fails
- Zero-byte file
- File extension does not match actual content
- File is partially downloaded
- File is locked by another process

## 12.2 Rendering

- Unsupported font
- Font substitution
- Missing embedded image
- Malformed XML inside Office file
- Broken ZIP container for DOCX/XLSX/PPTX
- Unusual page dimensions
- Very large images
- Millions of spreadsheet cells
- Complex nested tables
- Unsupported SmartArt
- Unsupported chart type
- Embedded media
- Macro-enabled document

## 12.3 Search

- No text layer
- Search query blank
- Search query one character
- Search query contains regex-like symbols
- Unicode search
- RTL search
- Very high number of matches
- File changed while searching
- User closes search during indexing

## 12.4 App Lifecycle

- App backgrounded while file loads
- App killed by OS
- Device rotates during loading
- Theme changes while reader open
- Low-memory event
- Incoming intent while another file is open
- Same file opened twice rapidly

## 12.5 Security

- Password-protected PDF
- Password-protected Office document
- Unsupported encryption type
- Malicious malformed document
- ZIP bomb Office file
- Path traversal attempts in packaged Office files
- Extremely compressed embedded asset

## 12.6 UX

- Filename longer than screen width
- File has no extension
- User taps multiple files quickly
- Reader fails after partial render
- Search result navigation reaches end
- Reading position points beyond current page count after document changed

---

# 13. Error States and User Messages

| Error | User Message | Suggested Action |
|---|---|---|
| Unsupported format | `OpenReader doesn't support this file type.` | Close / Open With |
| Corrupted file | `This document may be damaged or incomplete.` | Close / Try another app |
| File missing | `This file may have been moved or deleted.` | Remove from Recents |
| Permission lost | `OpenReader no longer has access to this file.` | Grant Access |
| Wrong PDF password | `Incorrect password.` | Retry |
| No searchable text | `No searchable text found.` | Close search |
| Out of memory protection | `This document is too large to render safely on this device.` | Close |
| Unsupported Office feature | `Some document elements may not be displayed correctly.` | Continue |

---

# 14. Performance Requirements

These are target benchmarks and must be validated against agreed reference devices.

| Area | Target |
|---|---|
| App cold start | Under 2 seconds on representative mid-range device |
| Indexed Home load | Under 1 second for normal library size |
| Small PDF open | Under 2 seconds |
| TXT open | Near-instant for normal files |
| Cached recent open | Under 1 second where renderer permits |
| Scrolling | Target 60 FPS |
| File scan | Progressive/non-blocking |
| Search | Progressive results; UI remains responsive |
| Large files | Lazy loading; bounded memory |

---

# 15. Offline and Privacy Requirements

## Mandatory

- No core feature requires internet.
- No document upload.
- No remote rendering.
- No cloud account.
- No document text sent to analytics.
- No filename sent to analytics.
- No reading history sent to analytics.
- No remote search processing.

## Recommended Android Configuration

If product requirements remain strictly offline, avoid requesting Internet permission unless required by a specific dependency. Dependencies should be audited to ensure they do not initiate network traffic.

---

# 16. Local Data Model

Suggested local entities:

## DocumentIndex

- id
- uri/path reference
- display_name
- extension
- mime_type
- size
- modified_at
- category
- last_seen_at

## RecentDocument

- document_id
- last_opened_at
- reader_type
- reading_position

## FavoriteDocument

- document_id
- favorited_at

## ReaderPosition

Possible fields by type:

### PDF

- page_number
- zoom_mode
- scroll_offset

### Word/TXT

- scroll_offset
- anchor if available

### Excel

- sheet_index
- row
- column
- horizontal_offset
- vertical_offset

### PowerPoint

- slide_index

---

# 17. Technical Deliverables

# 17.1 Product Deliverables

1. Approved BRD
2. UI/UX wireframes
3. Design system
4. Screen flow diagram
5. Flutter source code
6. Android application package
7. Release build configuration
8. File-format compatibility matrix
9. Test plan
10. QA test report
11. Performance test report
12. Privacy checklist
13. Open-source license report
14. User-facing privacy policy
15. Release notes

---

# 17.2 Engineering Deliverables

## Application Shell

- App navigation
- Theme system
- Local preferences
- Error handling framework

## File Layer

- Storage access abstraction
- Document scanner/indexer
- File metadata extraction
- Search/filter/sort

## Local Persistence

- Recent history
- Favorites
- Reader position
- Settings

## Reader Modules

- PDF reader
- Word reader
- Excel reader
- PowerPoint reader
- TXT reader
- CSV reader

## Platform Integration

- Android Open With / intent handling
- Share sheet
- Rotation handling
- File URI permissions

## QA Utilities

- Sample document test corpus
- Crash logging restricted to non-document-sensitive metadata, if any crash system is later introduced
- Performance instrumentation

---

# 18. QA Deliverables and Test Matrix

Each major format should be tested using a real-world corpus.

## Minimum Recommended Test Corpus

### PDF

- 50 standard PDFs
- 10 password-protected PDFs
- 10 scanned/image PDFs
- 10 large PDFs
- 10 malformed/edge-case PDFs

### DOC/DOCX

- 50 normal documents
- 20 table-heavy documents
- 10 image-heavy documents
- 10 complex layout documents
- 10 legacy DOC files

### XLS/XLSX

- 40 normal workbooks
- 10 large sheets
- 10 formula-heavy files
- 10 chart-heavy files
- 10 legacy XLS files

### PPT/PPTX

- 40 standard decks
- 10 image-heavy decks
- 10 chart-heavy decks
- 10 SmartArt/media-heavy decks
- 10 legacy PPT files

### TXT/CSV

- Different encodings
- Huge files
- Different CSV delimiters
- Multilingual data

---

# 19. Acceptance Criteria by Module

## File Discovery

- Supported files appear correctly.
- Unsupported files do not pollute normal lists.
- Re-scan does not duplicate entries.

## Recents

- Successful open updates Recents.
- Clearing Recents never deletes files.

## Favorites

- Favorite state persists across app restart.

## PDF

- Can open, navigate, zoom, search, and restore page.

## Word

- Common text/images/tables are readable.

## Excel

- Workbook sheets and cell values are readable.

## PowerPoint

- Slides render and can be navigated.

## Offline

- All core flows pass in airplane mode.

---

# 20. Security Requirements

- Validate file size before parsing.
- Add maximum decompression safeguards for Office container formats.
- Handle malformed documents without app termination.
- Avoid executing macros.
- Avoid executing embedded scripts.
- Treat hyperlinks as external navigation requiring explicit user action.
- Do not auto-launch embedded executables.
- Sanitize extracted temporary filenames.
- Restrict temporary files to app sandbox.
- Clear temporary rendering files according to cache policy.

---

# 21. Accessibility Requirements

- Support system text scaling where applicable.
- Buttons should have semantic labels.
- Touch targets should meet mobile accessibility guidance.
- Reader controls should support TalkBack where technically feasible.
- Contrast must remain readable in light/dark modes.
- Do not rely on color alone to communicate state.

---

# 22. Analytics Policy

Because OpenReader is positioned as fully offline and privacy-first, v1.0 should preferably ship without network analytics.

If local-only usage counters are ever needed, they should remain on-device.

Document-sensitive information must never be collected for analytics, including:

- Filename
- File path
- Document content
- Search terms
- Reading position tied to identifiable file metadata

---

# 23. Recommended MVP Release Scope

## P0 — Must Have

- Splash/init
- Storage access flow
- Home
- All Files
- Category filters
- File search
- File sort
- Recent Files
- Favorites
- Open With integration
- Share
- File Information
- PDF reader
- DOCX reader
- XLSX reader
- PPTX reader
- TXT reader
- Reading position persistence
- Light/Dark/System theme
- Offline operation
- Error states

## P1 — Strongly Recommended

- CSV reader
- Legacy DOC/XLS/PPT
- Advanced in-document search
- Folder browser improvements
- Better metadata extraction

## P2 — Future

- RTF
- ODT
- ODS
- ODP
- Advanced chart rendering
- More accessibility controls

---

# 24. Release Readiness Checklist

Before public release:

- [ ] All P0 screens complete
- [ ] All P0 flows tested offline
- [ ] No unintended network requests
- [ ] File-open intents tested across Android versions
- [ ] Storage permission flows tested
- [ ] Large-file memory tests completed
- [ ] Corrupted-file handling verified
- [ ] Password PDF flow verified
- [ ] Reader progress persistence verified
- [ ] Screen rotation tested
- [ ] App background/restore tested
- [ ] 100+ sample files per major format tested where possible
- [ ] Privacy policy reviewed
- [ ] Dependency license audit completed
- [ ] APK/AAB release build verified

---

# 25. Definition of Done

OpenReader v1.0 is considered functionally complete when a user can:

1. Install and launch the application.
2. Grant local document access.
3. Discover supported files.
4. Search and filter documents.
5. Open PDF, Word, Excel, PowerPoint, and TXT files.
6. Read documents fully offline.
7. Search inside supported documents.
8. Mark files as favorites.
9. View recent files.
10. Close and reopen the app.
11. Resume the previous reading location.
12. Handle unsupported, corrupted, missing, locked, or inaccessible files without crashing.

---

# 26. Product Positioning

**OpenReader**  
**PDF, Word, Excel & PowerPoint Reader**

Suggested short description:

> A fast, private, fully offline reader for PDF, Word, Excel, PowerPoint and text files.

Suggested privacy statement:

> Your documents stay on your device.

---

# 27. Key Product Risk

The main implementation risk is high-fidelity offline rendering of Office formats, particularly legacy `.doc`, `.xls`, `.ppt` and complex modern `.docx`, `.xlsx`, `.pptx` files.

Before final library selection, the engineering team should complete a proof-of-concept using real-world documents containing:

- Complex tables
- Non-standard fonts
- Charts
- SmartArt
- Images
- Merged spreadsheet cells
- Formula-heavy workbooks
- Large slide decks
- Embedded media
- Mixed-language and RTL content

The product requirement should be defined as:

> **Reliable, readable, high-fidelity offline viewing of common Office documents.**

It should not promise pixel-perfect Microsoft Office reproduction for every possible file.


---

# 28. Requirement Traceability Matrix

| Requirement ID | Requirement | Priority | Primary Screen/Module | Acceptance Evidence |
|---|---|---|---|---|
| ODF-001 | Discover supported local documents | P0 | Home / Files | Supported files appear after scan |
| ODF-002 | Search files by filename | P0 | Search | Partial/case-insensitive matches work |
| ODF-003 | Filter by document category | P0 | Home / Category | Correct format filter applied |
| ODF-004 | Sort files | P0 | Files / Category | Selected ordering is correct |
| ODF-005 | Open document from another app | P0 | Platform Integration | Android intent opens correct reader |
| ODF-006 | Maintain Recents | P0 | Home / Recents | Successful file open updates history |
| ODF-007 | Maintain Favorites | P0 | Favorites | Favorite state persists after restart |
| ODF-008 | Restore reading position | P0 | All Readers | Reopen resumes previous position |
| ODF-009 | Share original document | P0 | Reader / File Menu | System share sheet opens |
| ODF-010 | Display file metadata | P0 | File Information | Available metadata shown correctly |
| ODF-011 | Read PDF offline | P0 | PDF Reader | PDF opens with no network |
| ODF-012 | Search PDF text | P0 | PDF Reader | Search results navigable/highlighted |
| ODF-013 | Read DOCX offline | P0 | Word Reader | Common DOCX content readable |
| ODF-014 | Search DOCX text | P0 | Word Reader | Search works where parser permits |
| ODF-015 | Read XLSX offline | P0 | Excel Reader | Sheets and cell values viewable |
| ODF-016 | Search spreadsheet cells | P0 | Excel Reader | Matching cells navigable |
| ODF-017 | Read PPTX offline | P0 | PowerPoint Reader | Slides viewable/navigable |
| ODF-018 | Search slide text | P0 | PowerPoint Reader | Matching slide content found |
| ODF-019 | Read TXT offline | P0 | Text Reader | Text displays without network |
| ODF-020 | Read CSV as grid | P1 | CSV Reader | CSV rows/columns displayed |
| ODF-021 | Handle missing file | P0 | Error Handling | User sees recoverable message |
| ODF-022 | Handle corrupted file | P0 | Error Handling | No app crash; clear error shown |
| ODF-023 | Handle lost permission | P0 | Permission Flow | User can reauthorize access |
| ODF-024 | Support password PDF | P0 | PDF Reader | Correct password opens document |
| ODF-025 | Keep user content local | P0 | Entire App | Airplane-mode test passes |
| ODF-026 | Never modify original file | P0 | Entire App | Hash unchanged after reading |
| ODF-027 | Support dark/light/system theme | P0 | Settings | Theme changes and persists |
| ODF-028 | Clear Recents without deleting files | P0 | Recents / Settings | History clears; originals remain |
| ODF-029 | Clear app cache safely | P0 | Settings | Cache clears without deleting originals |
| ODF-030 | Remain responsive with large files | P0 | Reader Engines | UI remains responsive under test corpus |

---

# 29. Screen Feature Matrix

| Screen | Primary Features | Primary Actions | Empty/Error State | Persistence |
|---|---|---|---|---|
| Splash | Initialize local services | Automatic routing | Initialization recovery | Theme/settings |
| Permission Onboarding | Explain storage access | Allow / Not Now / Settings | Denied / permanently denied | Permission state |
| Home | Categories, Continue Reading, Recents | Open, search, refresh | No documents / no permission | Recents |
| All Files | All supported documents | Open, sort, filter, favorite | No files / inaccessible file | View mode/sort optional |
| Category Files | Format-filtered list | Open, sort, search | Empty category | Sort optional |
| Folder Browser | Folder traversal | Enter folder, open file | Empty/inaccessible folder | Last folder optional |
| Search | Filename search | Type, clear, open result | No results | Optional recent queries |
| Favorites | Favorite files | Open, remove favorite | No favorites | Favorite state |
| Recents | Reading history | Open, remove, clear all | No history | Recent state |
| PDF Reader | Pages, zoom, search, thumbnails | Read, search, jump, share | Corrupt/locked/unsupported | Page/zoom |
| Word Reader | Document flow/layout | Read, search, share | Unsupported elements/corrupt | Scroll/anchor |
| Excel Reader | Sheet grid | Switch sheet, search, scroll | Invalid workbook | Sheet/position |
| PPT Reader | Slides | Swipe, thumbnails, search | Invalid slide deck | Slide index |
| TXT Reader | Plain text | Search, font size, wrap | Encoding/binary issue | Scroll position |
| CSV Reader | Table grid | Search, scroll | Parse/delimiter issue | Position |
| File Information | Metadata | Share, favorite, open with | Metadata unavailable | N/A |
| Settings | Theme, reader, file options | Change settings, clear cache | N/A | Preferences |
| About/Privacy | Product/privacy information | View licenses/policy | N/A | N/A |

---

# 30. Delivery Phases

## Phase 1 — Foundation

### Deliverables

- Flutter project setup
- Navigation architecture
- Theme system
- Local database
- Storage access abstraction
- File scanner/indexer
- Home
- All Files
- Search
- Recents
- Favorites
- Settings shell

### Exit Criteria

- App can discover and list supported files.
- Search/filter/sort work.
- Local metadata persists.
- App works with internet disabled.

## Phase 2 — PDF Reader

### Deliverables

- PDF rendering
- Zoom
- Scroll/page modes
- Search
- Thumbnails
- Jump to page
- Password flow
- Reading position

### Exit Criteria

- PDF feature acceptance criteria pass using PDF test corpus.

## Phase 3 — Office Readers

### Deliverables

- DOCX reader
- XLSX reader
- PPTX reader
- Legacy format support where feasible
- Search within supported Office readers
- Reading state restoration

### Exit Criteria

- Office compatibility matrix completed.
- Unsupported constructs fail gracefully.

## Phase 4 — Text/CSV and Platform Integration

### Deliverables

- TXT reader
- CSV reader
- Android Open With integration
- Share sheet
- File Information

### Exit Criteria

- External-app open scenarios pass.

## Phase 5 — Hardening

### Deliverables

- Large-file optimization
- Low-memory handling
- Security hardening
- Corrupted-file handling
- Accessibility pass
- Performance testing
- Offline/network audit
- Dependency audit

### Exit Criteria

- Release readiness checklist complete.
- No core feature requires connectivity.

---

# 31. UI States Required Per Screen

Every data-driven screen should define at least these states:

1. **Loading** — data is being prepared.
2. **Loaded** — content available.
3. **Empty** — operation succeeded but no content exists.
4. **Error** — operation failed.
5. **Permission Required** — access is unavailable.
6. **Refresh/Retry** — user can retry safely.

Reader screens additionally require:

1. Initializing reader
2. Loading document
3. Rendering page/sheet/slide
4. Ready
5. Searching
6. Password required
7. Partially supported content
8. Corrupted/unsupported
9. File missing
10. Permission lost

---

# 32. Scenario Validation Matrix

| Scenario | Expected Result | Failure Handling |
|---|---|---|
| Fresh install with permission granted | Scan and show documents | Retry scan |
| Fresh install with permission denied | Limited mode | Show grant access action |
| Open local PDF | PDF Reader opens | Show read error |
| Open DOCX from another app | Word Reader opens | Unsupported/corrupt message |
| Reopen previously read file | Resume position | Fall back to start if invalid |
| Delete file externally | Missing-file warning | Remove stale entry |
| Revoke permission externally | Access warning | Reauthorize |
| Open password PDF | Prompt for password | Retry/cancel |
| Open scanned PDF and search | No searchable text state | Explain OCR not available |
| Open massive workbook | Lazy/controlled rendering | Abort safely if device limit reached |
| Rotate device in reader | Layout adapts | Maintain approximate position |
| App killed in background | State restored next launch | Use last committed position |
| Open two files rapidly | Latest intended navigation wins | Cancel stale load |
| Clear cache | Reader originals unaffected | Rebuild cache as needed |
| Clear Recents | Files remain untouched | Confirm destructive scope only affects history |
| Airplane mode | Full reader operation | No connectivity error shown |

---

# 33. Final Handover Package

The completed OpenReader v1.0 project handover should contain:

```text
OpenReader/
├── BRD/
│   └── OpenReader_BRD_v1.0.md
├── UX/
│   ├── User_Flows.pdf
│   ├── Wireframes.pdf
│   └── Design_System.pdf
├── Engineering/
│   ├── Architecture.md
│   ├── Dependency_Matrix.md
│   ├── File_Format_Support.md
│   └── Build_Instructions.md
├── QA/
│   ├── Test_Plan.md
│   ├── Test_Cases.xlsx
│   ├── Compatibility_Matrix.xlsx
│   ├── Performance_Report.md
│   └── Release_Checklist.md
├── Privacy/
│   ├── Privacy_Policy.md
│   └── Offline_Network_Audit.md
└── Release/
    ├── app-release.aab
    ├── app-release.apk
    └── Release_Notes.md
```

This structure is a recommended delivery package, not an assertion that each artifact exists yet.

