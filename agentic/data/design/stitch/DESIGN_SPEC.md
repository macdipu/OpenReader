# OpenReader UI Design Spec (Stitch mockups → Flutter)

Two design systems: **OpenReader** (light) and **Nocturne Reader** (dark/AMOLED). Both ship in the app; light↔dark should swap tokens 1:1. AMOLED variant uses `#000000` true-black canvas (not just `background` token) for OLED power saving.

## 1. Design tokens

### Color roles (light → dark)

| Role | Light (OpenReader) | Dark (Nocturne) |
|---|---|---|
| background/surface | `#F8FAFC`/`#f8f9ff` | `#000000` (canvas) / `#0f131c` (surface) |
| surface-container-lowest | `#FFFFFF` | `#0a0e17` |
| surface-container-low | `#EFF4FF` (`#F1F5F9`) | `#181b25` |
| surface-container | `#E5EEFF` | `#1c1f29` |
| surface-container-high | `#DCE9FF` | `#262a34` |
| surface-container-highest | `#D3E4FE` | `#31353f` |
| on-surface | `#0B1C30` (`#0F172A`) | `#dfe2ef` (`#f1f5f9`) |
| on-surface-variant | `#45474C` (`#475569`) | `#bdc8d1` (`#94a3b8`) |
| outline | `#75777D` | `#87929a` |
| outline-variant / border | `#C5C6CD` (`#E2E8F0` hairline) | `#3e484f` (`#1e293b` hairline, `#334155` focus) |
| primary | `#091426` | `#8ed5ff` |
| primary-container | `#1E293B` | `#38bdf8` |
| secondary (accent/CTA) | `#0051D5` | n/a — Nocturne uses `primary` as accent |
| secondary-container | `#316BF3` | — |
| tertiary | `#00190E` (readable green `#24A375`/`#10B981`) | `#4ee6aa` |
| tertiary-container | `#00301F` | `#22c990` |
| error | `#BA1A1A` | `#ffb4ab` |
| error-container | `#FFDAD6` | `#93000a` |

### Format accent colors (both themes — semantic, not tonal-swapped)

| Format | Primary | Tint (light) | Nocturne accent |
|---|---|---|---|
| PDF | `#DC2626` (red-600) | `#FEF2F2` | `#38bdf8` (sky/electric blue) |
| DOCX | `#2563EB` (blue-600) | `#EFF6FF` | `#818cf8` (indigo) |
| XLSX | `#059669` (emerald-600) | `#ECFDF5` | `#34d399`/`#4ee6aa` (mint) |
| PPTX | `#D97706` (amber-600) | `#FFFBEB` | `#fb923c`/amber-400 |
| TXT/CSV | `#0891B2` (cyan-600) / teal | `#ECFEFF` | slate/outline |

Badge shape: 44×44dp (list) or 28×28dp (app bar chip) rounded-lg (8dp), 2-line stacked label (3-letter code + icon), border 1px at 20-60% opacity of the accent.

### Typography (light = Inter/JetBrains Mono; dark = Space Grotesk headlines + Inter body + JetBrains Mono mono)

| Style | Size/LH/Weight/Tracking | Light font | Dark font |
|---|---|---|---|
| display-lg | 56/64/700/-3% | — | Space Grotesk |
| headline-lg | 28/34/700/-2% (mobile 24/30) | Inter | Space Grotesk (36/44/600/-2%, mobile 28/36) |
| headline-md | 20/26/600/-1.5% | Inter | Space Grotesk (24/32/600/-1.5%) |
| headline-sm | 16/22/600/-1% | Inter | Space Grotesk (20/28/500) |
| title-md | 15/20/600/-1% | Inter | — (use headline-sm/body-lg) |
| body-lg | 16/24/400 | Inter | Inter (18/30/400/+1%) |
| body-md | 14/20/400 | Inter | Inter (16/26.4/400) |
| body-sm | 12/16/400 | Inter | Inter (14/22/400) |
| label-lg | 13/18/600/+1% | Inter | — |
| label-md | 11/14/600/+4% | Inter | JetBrains Mono (13/20/500/+3%) |
| label-sm | 10/12/700/+6% | Inter | JetBrains Mono (11/16/500/+5%) |
| mono-metadata | 11/14/500 | JetBrains Mono | JetBrains Mono |

### Spacing & shape

- Spacing scale: xs=4, sm=8, md=12(light)/16(dark), lg=16(light)/24(dark), xl=24(light)/40(dark); gutter=16, margin=16(mobile)/24(tablet, light) or 16/32 (dark).
- Radius (light "Level 2"): sm=4, DEFAULT=8, md=12, lg=16, xl=24, full=9999 (pills/FAB/toolbar).
- Radius (dark "Soft Level 1", tighter): DEFAULT=2, lg=4, xl=8, full=12 (dark UI reads more rectangular/technical; only floating pills/HUD/beacons are fully round).
- Touch targets: 48×48dp minimum (Android). List row min-height 72dp (rich) / 56dp (compact, dark reader lists).
- Elevation: no drop shadows on dark canvas — use 1px hairline borders + `box-shadow: 0 0 16px rgba(accent,0.25)` glow on focus/active only. Light theme uses soft shadows: `0 1px 3px rgba(15,23,42,.04)` (card), `0 8px 24px -4px rgba(15,23,42,.08)` (floating toolbar), `0 16px 32px -8px rgba(15,23,42,.14)` (modal/sheet).

---

## 2. Per-screen spec

### 01-settings-storage.html — Settings & Storage
- TopAppBar (menu icon, "Settings" headline, SANDBOXED pill badge, search icon) → body scroll → BottomNavBar (Settings tab active).
- Sections (each: label-lg uppercase caption + mono-metadata tag on the right, then a card):
  1. **Privacy banner**: icon tile + headline-sm + "100% Offline" pill + body-sm description.
  2. **General Appearance** card: 3-segment button row (Light/Dark/System, active = raised surface-container-lowest chip w/ shadow); divider; "Pure Black AMOLED Contrast" row with Material switch (toggles true `#000000` bg in dark mode).
  3. **Reading Engine Preferences** card (divided rows): Default Reader Mode (2 selectable tiles: Continuous Scroll [selected, 2px secondary border] vs Page by Page Flip); Keep Screen Awake switch (on); Default Scale Preset (3 segmented buttons: Fit Width [selected, primary-container fill] / 100% Actual / Fit Page).
  4. **Storage & Cache Manager**: 2-col bento grid — "48 indexed documents" card (icon, big number, "Rescan Local Storage" button) + "14.2 MB cached render tiles" card ("Clear Render Cache" destructive-outline button, error color).
  5. **Privacy & System Integrity** card (divided rows): Scoped Storage Sandbox (check icon), Open-source licenses (chevron), App Version (mono badge "v1.0.4").

### 02-word-docx-reader.html — Word (DOCX) Reader (light)
- Header: back arrow, small "DOC" badge tile, title+filename, SANDBOXED+size subline, trailing search/star/more icons.
- Sub-toolbar (surface-container-low strip): font-size stepper (A−/A+), Sans/Serif pill toggle, margin-align icon button, trailing "Page 4 of 12 • 34%" pill badge.
- Body: paper-card (rounded-xl, ring border, min-height ~750dp) containing doc metadata header (DOCX version tag, title h2, author/date/rev metadata row), section heading, body paragraphs, a left-accent-bordered callout box (icon+title+body), a bordered data table, a checklist (checked items = filled secondary-container check tile; unchecked = outlined tile), footer (engine name • doc id • page).
- Floating bottom toolbar: capsule pill (54dp), ToC icon, prev/next chevrons + scrub track+thumb + "4/12" label, font-size icon, fullscreen icon.

### 03-storage-access-security.html — Storage Access & Security (onboarding/permission)
- No bottom nav (task-focused). Header: menu icon, "OpenReader" wordmark, "100% OFFLINE" pill, search.
- 2-column bento (stacks on mobile): **Left (7/12)** — security shield badge pill, concentric-ring shield hero graphic with "LOCAL_ONLY"/"NO_CLOUD" floating micro-badges, headline "Your Documents, Completely Private & Offline", body copy, 3 checklist value-prop cards (Scoped Storage Access / Zero Cloud Sync / Multi-Format Engine), "Native Decoders Built-In" format-pill row (PDF/DOCX/XLSX/PPTX/TXT/CSV), 2 CTA buttons ("Grant Local Storage Access" filled secondary, "Select Specific Folder Only" outline).
- **Right (5/12)** — password-protected-document dialog card: key icon header, doc metadata strip (badge+name+size+"Encrypted"), password input field w/ visibility toggle, "Decryption happens in local device memory only" note, cipher/KDF/network-access spec rows (mono), Cancel/Unlock&Read actions. Below: privacy assurance footnote card.
- Use for: the app's storage-permission / password-unlock dialog flow.

### 04-powerpoint-pptx-reader.html — PowerPoint Reader (light)
- Header: back, orange "PPT" badge + filename + offline-dot+size subline, trailing search/slideshow(secondary)/more.
- Sub-header: slide-position pill ("Slide 6 of 28" w/ layers icon + unfold chevron, tappable → jump modal), prev/next stepper + fit-screen icon.
- Main: 16:9 slide canvas card — header (pillar tag + title h1 + "Q4 PROJECTIONS" mono badge), 3-metric bento grid (icon+delta-chip+big stat+label), quarterly trajectory mini bar-chart row, footer (date • "Strictly Confidential").
- Footer: thumbnail filmstrip (horizontal scroll, active thumb = ring-2 secondary highlight) + floating pill capsule (Present / grid / speaker-notes / star icons).

### 05-excel-xlsx-viewer.html — Excel (XLSX) Viewer (light)
- Header (surface-container-lowest, no blur): back, "XLS" tertiary-container badge, filename+dot+"Read Only • Offline • size" subline, search/filter/more icons.
- Formula bar (h-11, surface-container-low): active-cell pill ("D8"), formula display ("fx =SUM(D2:D7)"), computed-result pill (secondary-fixed bg).
- Main: scrollable HTML-table-like grid — sticky header row + sticky first column, alternating row shading, column headers show letter+name+sort-chevron, active/selected row+cell has 2px secondary border + drag-fill-handle dot, status pills ("On Track" tertiary / "Review" error) per row.
- Floating pill (bottom): Fit / Frozen(A,1) lock indicator / zoom −/100%/+.
- Footer: sheet tabs (active = surface-container-high + underline bar) + sheet count + add-sheet button.

### 06-favorites-history.html — Favorites & History
- Header: menu, "OpenReader" title, Sandboxed pill, search/sort icons.
- Segmented tabs (Favorites [12] / Reading History [24], active = raised surface-container-lowest chip).
- Quick-action row: "Create Collection" + "Organize" chip buttons, "Clear History" text-icon button (right).
- Horizontal format filter chips (All[primary-filled+count]/PDF/Word/Excel/PPTX, each w/ colored dot + count bubble).
- Document rows (rich, 3.5-space padding): format-badge tile (icon+label stacked) → title + "size • opened Xh ago • Page N of M (P%)" metadata row → **reading-progress bar** (1.5dp, secondary fill) under metadata → trailing star(filled=favorited)/overflow icons.
- Footer banner: "Local Encrypted Vault • 0 telemetry sent" + "35.5 MB Total" mono stat.
- BottomNavBar (Favorites active).

### 07-local-search-filter.html — Local Search & Filter
- Header: offline-shield micro-row + "Storage: /path" mono caption; search shell row (back, pill search-input w/ leading search icon, trailing clear+tune icons); horizontal filter-chip carousel (All Formats[primary] / PDF / Word / Excel / PPTX[disabled/greyed, count 0]).
- Results header: dot + "N files found" + Sort dropdown ("Relevance ▾").
- Result cards: format badge (2-line: code+version/type) + title with `<mark>` highlighted matched substrings (secondary-fixed bg) + metadata row (size • modified date • "Device storage" pill) + star/overflow actions; top hit also shows a **content-snippet callout** (left-accent-border box, "Matches in Title and Content" label + italic quoted excerpt with highlighted term + "Page N • Section X" mono tag).
- Footer section: "Recent & Suggested Inquiries" — history-icon chips (clock icon + query text) + "+ New query tag" chip.
- BottomNavBar (Files active — search entered from Files tab).

### 08-home-discovery-hub.html — Home Discovery Hub
- Header: menu, "OpenReader" title, search/overflow icons.
- Search bar (rounded-xl input w/ tune/filter trailing icon).
- "Formats" horizontal chip row (All[primary, count]/PDF/Word/Excel/PowerPoint/Text, each colored dot + count) + "N files indexed" caption.
- "Continue Reading" horizontal snap-scroll cards (290dp wide): top 1px progress bar (proportional fill), format-badge+title+"p.X/Y • P%" row, footer "Xh ago" + Resume/Open pill button (filled = highest-progress item).
- "Recent Documents" vertical list: compact row (format badge, title [+ optional filled star if favorited], "size • date • Format" mono caption), trailing overflow icon.
- Floating action pill (bottom-right, above nav): "Scan Storage" (sync icon + label, primary-filled).
- BottomNavBar (Home active).
- **Use this as the canonical Home/Discovery screen** — the app's home_view should adopt this structure (search + format chips + continue-reading carousel + recents list + scan FAB).

### 09-offline-pdf-reader.html — PDF Reader (light)
- Header 2-row: primary row (back, PDF icon+title, search[active]/bookmark/more) + inline search sub-row (find-in-doc input w/ "3 of 18" match counter + prev/next match steppers).
- Main: single "page" card (max-w 560, serif-adjacent paper), header (section tag + title), intro paragraph, **financial line-item table** (flat rows, active/matched row = amber highlight+left-border, subtotal rows = bold/tinted), mini bar-chart (quarterly), footer page number.
- Right-edge vertical scrub rail (thin track + position thumb + floating page-number bubble).
- Floating bottom stack: pill scrub bar (page N / total, slider w/ thumb + floating "18/54" tooltip on drag) + capsule multi-tool bar (View-mode label toggle, fit-width, thumbnail-grid, day/sepia/night toggle) — the capsule uses **primary-container** fill (darker, distinct from the pill above it).

### 10-all-files-explorer.html — All Files Explorer
- Header: menu, "All Files" + "LOCAL" mono tag, search/folder-view/sort icons.
- Format filter pills (All[primary]/PDF/Word/Excel/PPT/Text-CSV, count bubbles).
- Storage summary micro-banner (icon, "48 documents… 124.6 MB total • Zero network sync", "Sandboxed" pill).
- Sort/view sub-bar: "Date modified ↓ · Newest first" chip + list/grid/multi-select icon cluster (list = active/secondary).
- File rows (44×44 2-line format badge incl. small icon under 3-letter code; lock icon next to title if password-protected) + metadata (size • pages/sheets/slides • date) + star/overflow.
- **Bottom sheet modal** (on row tap): drag handle, selected-file header (badge+name+meta+close), action list rows (icon-tile + title + subtitle + optional chevron): Open in Reader, Add to Favorites, Share File, File Information, Open With (External App).
- BottomNavBar (Files active).

### 11-file-metadata-diagnostics.html — File Metadata & Diagnostics
- Presented as a bottom-sheet/dialog (rounded-t-3xl mobile, centered rounded-3xl on tablet+), scrim backdrop, drag handle, close(X) button — no bottom nav.
- Header: file-icon tile + "File Information & Diagnostics" headline + "Sandboxed Local Document Inspector" subtitle.
- Doc identity card: format badge (14×14) + filename + "Local Only" verified pill + size/pages/modified row.
- "System Attributes" bento grid: Storage Location (full-width, mono path + Copy Path button), MIME Type, Physical Size (bytes + human size), Access Permissions (shield icon + scope text), Timestamp, Checksum SHA-256 (full-width, mono hash + copy button + "Match Verified" pill).
- "Engine Diagnostics" section: success alert banner (tertiary-tinted, "Offline Document Integrity Verified") + non-blocking warning banner (surface-container, "Handled Font Warning" + "NON-BLOCKING" tag).
- Footer actions: destructive text-button "Remove from Index" (error, left) + outline "Share Copy via System Sheet" + filled "Open in Slide Viewer" (right cluster).
- **Use for**: `file_information` feature screen — map directly, this is a near-exact spec match.

### 13-amoled-word-docx-reader.html — AMOLED DOCX Reader
- True black body bg; fixed header (14dp shorter than light: h-14) blurred `surface-container-lowest/90`: back, small outline DOCX tag chip + title, search/format_size/bookmark/more icons (all `on-surface-variant`, hover→primary).
- Secondary HUD toolbar (fixed, below header): Sans/Serif toggle, font-size stepper w/ current pt shown, line-spacing 1.2/1.5/2.0 selector, "OLED Black" active-state pill (glowing dot + luminescent border) pinned right.
- Body: dark paper card (`#070a10` bg, hairline border) — meta strip (timestamp + "SECTION X OF Y"), headline, body paragraph, **indigo-accented callout box** (glow shadow, icon+label+body), metric table (label/value rows, value colored primary/tertiary per metric), closing paragraph.
- Fixed reading-status HUD pill (bottom, above nav): chapter icon+name, divider, "42% • 12 min read left".
- BottomNavBar: 5 icon-only buttons (auto_stories/zoom_in/view_carousel/format_size/tune); active = filled surface-container-high pill + primary icon + glow shadow ring.

### 14-amoled-pdf-reader.html — AMOLED PDF Reader
- Simulated status bar row (h-6, clock+AMOLED-HDR label+wifi/battery icons) — **do not implement in-app** (real OS status bar handles this); keep as reference only.
- Header: back, glowing-dot "PDF" outline chip + title, search/invert-colors(night-mode, primary+glow dot)/more.
- Canvas: page card bg `#121824` w/ subtle dot-grid watermark, meta strip (section tag + "SHA-256 VERIFIED" w/ lock icon), title+description, **schematic diagram box** (`#0a0e17`, node cards connected by gradient line w/ glowing dot, spec-metrics footer strip), **dark code-block** (mac-dots header + filename + copy button, syntax-highlighted mono text), body paragraph, page-number footer.
- Floating page-nav pill (glass, luminescent border): prev chevron, "Page N / Total", micro scrub track (glowing fill), next chevron.
- Floating vertical zoom stack (right edge): +, 100% label, −, fit-screen, each in glass capsule.
- BottomNavBar: view_carousel active (glow ring) — same 5-icon pattern as DOCX reader.

### 15-amoled-excel-xlsx-viewer.html — AMOLED Excel Viewer
- Status-bar row like PDF (reference only, skip in-app). Header offset by 6dp for status row, else same pattern; XLSX badge uses **tertiary/mint** color not blue.
- Formula toolbar: ƒx icon tile, cell-address pill (primary), formula string (segmented colored spans), computed-result pill (tertiary-tinted, "RES: $value").
- Grid: pure-black table, sticky header row (`#0a0e17`) + sticky first col, zebra rows (`#090d16`/`#0e1422`), header col labeled "A • Category" style, active column tinted `tertiary/5`, **active cell** gets thick tertiary border + corner drag-handle + `cell-glow` box-shadow.
- Sheet-tab footer bar (fixed above bottom nav): active tab = pulsing dot + tertiary border + glow; row/col count badge right.
- BottomNavBar: view_carousel active, matches other AMOLED readers.

### 16-amoled-powerpoint-pptx-reader.html — AMOLED PPTX Reader
- Header: back, title + amber-outline "PPTX" chip, grid-view/present(glow)/more icons.
- Stage: "LIVE STAGE • 16:9" telemetry row + "Slide N of M" pill, then 16:9 slide card (`#0c101a`, dot-grid watermark, glow shadow) — header (amber category tag + title + timestamp chip), 3-card bento (icon-tile+badge+title+caption, middle card amber-highlighted = "active" emphasis), status footer (pass/RAM indicator dots + "CONFIDENTIAL" tag), floating prev/next chevron buttons overlaid left/right edge.
- Presenter micro-bar (below stage): "Presenter Notes (N)" chip, Pointer toggle (red dot, hover→red text), auto-advance timer chip (mono countdown).
- Filmstrip: horizontal thumbnails (16:9, opacity-60 inactive→100 hover, active = wider + amber 2px border + glow + "[ACTIVE]" label + colored content blocks).
- BottomNavBar: same 5-icon pattern, view_carousel active.

---

## 3. Cross-screen component library (canonical specs)

### TopAppBar
- Light: h-64dp, bg = `surface`/95% blur, bottom hairline only on some screens (favorites/all-files use border, home/settings don't — treat as optional). Leading: 40-48dp icon button (menu or back). Center/adjacent: headline-md bold title, optional format badge (28×28 rounded-lg) + subtitle row for reader screens. Trailing: 40-48dp icon buttons, 0-2px gap, optional status pill ("100% OFFLINE"/"SANDBOXED" — mono-metadata, pill, surface-container-lowest bg, hairline border, verified_user icon).
- Dark/AMOLED: h-56dp (shorter), bg `surface-container-lowest/90` + blur, **always** bottom hairline border. Icons default `on-surface-variant`→`on-surface`/`primary` on hover/active. Format chip is outline-style (10% bg tint + 30% border of accent color, not filled).
- Reader variant adds a second fixed row directly below (secondary HUD toolbar) for text tools or find-in-doc — light readers use `surface-container-low` bg; dark readers use `surface-container-lowest/95`.

### File/Document list row
- Rich variant (Favorites/Home/Search, ~72-80dp): format badge 44×44 rounded-lg (icon + bold 3-4 letter code, tinted bg 50-level + border), title (title-md, truncate), metadata line (size • relative-time • extra mono badge), optional 1.5dp progress bar beneath metadata (secondary fill, rounded), trailing star + overflow (40×40 circular icon buttons).
- Compact variant (All Files/Recent, 56-64dp): same badge smaller icon variant, single metadata line, trailing star+overflow.
- Hover/press: border → secondary/40-50%, background unchanged (light) or `surface-container-lowest` (dark hover row bg shift).
- Dark AMOLED list row (spec-only, not yet in a screen): 56dp min-height, bg `#000000`→hover `#0a0e17`, 1px left accent border in format color on hover, 1px bottom divider `#1e293b`.

### Format badge (standalone chip, e.g. in headers)
- 22-28dp height, px-1.5/2, rounded (DEFAULT/lg), bg = accent 10% alpha, border = accent 25-40% alpha, text = accent, font mono-metadata/label-sm bold uppercase tracking-wide. Optional small pulsing dot before text on dark screens.

### BottomNavBar
- Light: h-80dp, bg `surface-container-lowest` (95% blur variant on some), safe-area padding, 4 destinations (Home/Files/Favorites/Settings). Inactive: `on-surface-variant` icon+label stacked, label-md. Active: pill wrapper (`secondary-fixed/50` bg, rounded-full, px-5 py-1), icon filled variant, `secondary` color, bold label.
- Dark/AMOLED (reader context — 5 destinations, no persistent "library" nav since it's task-focused): h-64dp, bg `surface-container-lowest/90` blur, top hairline border. Inactive: `on-surface-variant` icon only (no label) in plain button. Active: `surface-container-high` filled circle, `primary` icon, primary/30% border, glow shadow ring — icons are auto_stories / zoom_in / view_carousel / format_size / tune (reader tools, not app navigation — this nav bar replaces the library nav while inside a reader).

### Floating reader toolbar / HUD pill
- Light: capsule (`border-radius:9999px`), h-52-54dp, bg `surface-container-lowest/95` blur, hairline border, positioned `bottom-24` centered, shadow-lg. Contains icon buttons + a scrub slider (flex-1) with track `surface-container-high`, fill `secondary`, thumb 16dp circle w/ 2px secondary ring, floating "N/Total" tooltip above thumb while dragging.
- Dark: same capsule shape but bg `rgba(10,14,23,.88)` + `backdrop-filter: blur(16px)`, hairline `#1e293b`, glow shadow (`luminescent-glow`), track fill uses `primary` (blue) with drop-glow (`box-shadow 0 0 8px rgba(primary,.8)` on fill).

### Search field
- h-48dp, rounded-lg(10dp)/xl, bg `surface-container-low`(light)/`surface-container-lowest`(dark), no border until focus → 1.5-2px `secondary`(light)/`primary` or format-accent (dark) border + soft glow ring. Leading search icon (outline/secondary tint), trailing clear(x) + tune/filter icon buttons.

### Filter/category chip
- h-36dp, pill, inactive = `surface-container-low`/`surface-container-lowest` + hairline border, text `on-surface`/`on-surface-variant`; active = `primary` fill + `on-primary` text (or `surface-container-high`+accent border on dark). Trailing count badge: small pill/circle, `surface-container-high` bg (inactive) or `primary-container` (active), mono-metadata or label-sm text.

### Checkbox
- 20×20dp (light, 6dp radius) / 18×18dp (dark, per Nocturne spec). Unchecked: `surface-container-low`/`surface-container-lowest` bg + 1px `outline-variant`/`334155` border. Checked: solid accent fill (`secondary` light / format-accent or `primary` dark), contrasting checkmark glyph.

### Card / section container
- Light: `surface-container-lowest` bg, 1px `outline-variant/30` border, `rounded-xl` (12dp), shadow `0 1px 3px rgba(15,23,42,.04)`, internal padding 16dp (`p-4`).
- Dark: `surface-container-lowest` (`#0a0e17`) or explicit `#121824`/`#070a10` bg, 1px `#1e293b` border, tighter radius (2-8dp per Nocturne "soft level 1"), no ambient shadow — glow only on focused/active state.

### Modal / bottom sheet
- Scrim: `primary/40` + `backdrop-blur-sm`. Sheet: `surface-container-lowest`, `rounded-t-3xl` (mobile) / `rounded-3xl` centered (tablet+), drag handle (40×4dp, `outline-variant/60`, centered, mb-4), header row (icon+title+subtitle / close button), scrollable body, optional footer action bar (`surface-container-low/60` bg, border-t, button cluster right-aligned + destructive text-button left-aligned).

### Progress / scrub bar (inline, e.g. favorites reading progress)
- Track h-1.5dp, `surface-container-high` bg, rounded-full, fill `secondary` (light) / format accent (dark), width = % complete, `transition-all duration-300`.
