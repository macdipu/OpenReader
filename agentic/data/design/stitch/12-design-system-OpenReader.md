---
name: OpenReader
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#45474c'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#75777d'
  outline-variant: '#c5c6cd'
  surface-tint: '#545f73'
  primary: '#091426'
  on-primary: '#ffffff'
  primary-container: '#1e293b'
  on-primary-container: '#8590a6'
  inverse-primary: '#bcc7de'
  secondary: '#0051d5'
  on-secondary: '#ffffff'
  secondary-container: '#316bf3'
  on-secondary-container: '#fefcff'
  tertiary: '#00190e'
  on-tertiary: '#ffffff'
  tertiary-container: '#00301f'
  on-tertiary-container: '#24a375'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e3fb'
  primary-fixed-dim: '#bcc7de'
  on-primary-fixed: '#111c2d'
  on-primary-fixed-variant: '#3c475a'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#b4c5ff'
  on-secondary-fixed: '#00174b'
  on-secondary-fixed-variant: '#003ea8'
  tertiary-fixed: '#85f8c4'
  tertiary-fixed-dim: '#68dba9'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005137'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.06em
  mono-metadata:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  margin: 1rem
  margin-tablet: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system defines an offline-first, privacy-respecting Android document reading environment built in Flutter. The visual philosophy blends the structural discipline of Material Design 3 with high-craft European typography and Swiss graphic restraint. It eliminates unnecessary skeuomorphic tropes in favor of immediate legibility, crisp structural framing, and calm, distraction-free utility.

### Emotional Tone & Philosophy
- **Local Sovereignty:** Visuals emphasize local-device ownership and speed—zero telemetry indicators, instant transitions, and local-first status tokens.
- **Precision Utility:** Information density is tuned specifically for quick document scanning, catalog management, and extended reading sessions without optical fatigue.
- **Architectural Clarity:** Layouts favor clear spatial planes, subtle 1px division, and deliberate tonal surfaces over heavy dropped shadows.

## Colors

The system relies on a high-contrast slate anchor hierarchy complemented by semantic format indicators engineered for immediate document differentiation during rapid scrolling.

### Surface & Foundation Tokens
- **Canvas / Background:** `#F8FAFC` (Slate 50) establishes a soft, non-reflective base that avoids pure-white screen glare.
- **Surface Elevation 0 (Pure):** `#FFFFFF` used for cards, reading canvases, and interactive dialog sheets.
- **Surface Elevation 1 (Containers):** `#F1F5F9` (Slate 100) used for secondary chip fills, search inputs, and inactive control badges.
- **Structural Borders:** `#E2E8F0` (Slate 200) for hairline 1px borders and list separators.

### Typography & Content
- **Text Primary:** `#0F172A` (Slate 900) for high-legibility file titles and navigation headlines.
- **Text Secondary:** `#475569` (Slate 600) for document metadata, size, timestamps, and page ratios.
- **Text Tertiary / Muted:** `#94A3B8` (Slate 400) for placeholder text and inactive tab labels.

### Format Semantic Accents
Format badges pair a vivid primary marker with an ultra-light tint background container:
- **PDF:** Primary `#DC2626` (Crimson), Tint `#FEF2F2` (Red 50).
- **DOCX:** Primary `#2563EB` (Royal Blue), Tint `#EFF6FF` (Blue 50).
- **XLSX:** Primary `#059669` (Emerald), Tint `#ECFDF5` (Green 50).
- **PPTX:** Primary `#D97706` (Amber), Tint `#FFFBEB` (Amber 50).
- **TXT / CSV / MD:** Primary `#0891B2` (Cyan Slate), Tint `#ECFEFF` (Cyan 50).
- **Security / Offline Shield:** Primary `#10B981` (Emerald 500) paired with `#0F172A` to denote fully local sandboxed operations.

## Typography

Typography is set strictly in Inter, complemented by JetBrains Mono exclusively for file sizes, hashing verification, page pagination (e.g., `p. 148 / 620`), and memory allocations.

### Typographic Discipline
- **Headlines:** Use tight negative letter spacing (`-0.015em` to `-0.02em`) to guarantee tight line cohesion in document folders and library screens.
- **File Lists:** File titles employ `title-md` (15px/SemiBold) allowing 2-line wrap with truncation, paired with `mono-metadata` for precise alphanumeric alignment of timestamps and file capacities.
- **Format Indicators:** `label-sm` utilizes uppercase tracked styling (`letterSpacing: 0.06em`) within compact file badges.

## Layout & Spacing

The layout operates on a standard Android 4dp/8dp incremental system with strict touch target compliance (minimum 48×48dp for all interactive elements).

### Grid & Responsiveness
- **Mobile (portrait, < 600dp):** Single-column fluid view. Standard outer canvas margin is `margin` (16dp). File lists stretch across the width; grid modes display a 2-column layout with a 12dp gutter.
- **Tablet / Large Foldables (>= 600dp):** Fluid 2-pane master-detail arrangement. Master navigation list locks to a 360dp width; preview canvas expands dynamically to fill remaining real estate. Outer margins scale to 24dp.
- **In-Reader Shell:** Edge-to-edge layout with dynamic window insets (`WindowInsetsCompat`), automatically tucking toolbars beneath display cutouts and navigation bars.

## Elevation & Depth

Visual depth is achieved primarily through tonal layering and hair-thin structural boundaries (`#E2E8F0`), rather than heavy drop shadows, preserving an agile and performant rendering pipeline in Flutter.

### Elevation Hierarchy
- **Level 0 (Flat Ground):** Background `#F8FAFC`. List items sit directly on Level 0 separated by a 1px baseline stroke.
- **Level 1 (Card & Content Blocks):** Fill `#FFFFFF`, 1px solid border `#E2E8F0`, ambient shadow `box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04)`.
- **Level 2 (Floating Action Toolbar & Controls):** Fill `#FFFFFF` with 94% opacity blur filter (`backdrop-filter: blur(16px)`), border `#CBD5E1`, shadow `0 8px 24px -4px rgba(15, 23, 42, 0.08)`.
- **Level 3 (Modals & Sheet Drawers):** Fill `#FFFFFF`, shadow `0 16px 32px -8px rgba(15, 23, 42, 0.14)`.

## Shapes

The shape system employs targeted rounding (Level 2) to maintain a modern, precise look without excessive pillowy radius styling.

### Shape Assignment Rules
- **Category Chips & Status Badges:** Fully rounded pills (`border-radius: 9999px`) for quick tactile scanning.
- **File List Cards:** `border-radius: 12px` (`0.75rem`), balancing internal 8dp icon shapes and nested badges cleanly.
- **Action Buttons & Inputs:** `border-radius: 10px` (`0.625rem`) providing tactile clarity.
- **Bottom Navigation Pill Indicators:** `border-radius: 16px` for active indicators wrapping icon-label pairs.
- **Floating Reader Toolbar:** `border-radius: 9999px` (floating capsule bar).

## Components

### 1. Android TopAppBar
- **Structure:** 64dp standard height. Neutral background `#F8FAFC` blending seamlessly with the canvas.
- **Elements:** Left navigation icon (Drawer/Back, 48dp touch target), central section headline (`headline-md`), right-aligned action cluster containing Search trigger, Sort modal toggle, and an Overflow menu (`#1E293B` icons).
- **Offline / Shield Indicator:** Optional left-of-overflow lock/shield micro-badge displaying a green checkmark indicating 100% sandboxed offline storage.

### 2. File List Item Cards
- **Structure:** Horizontal flex arrangement, 72dp min height, white container, 1px `#E2E8F0` border, 12dp rounded corners.
- **Left (Format Marker):** 44×44dp square badge with 8dp rounded corners. Uses format semantic tint (e.g., `#FEF2F2` for PDF) with bold centered uppercase extension text (`label-sm`, `#DC2626`).
- **Center (Metadata):** Primary file name (`title-md`, `#0F172A`, 1-2 lines with ellipsis). Subtitle row displays human-readable file weight (e.g., `4.2 MB`), middle dot separator `•`, and relative date (`body-sm`, `#64748B`).
- **Right (Quick Actions):** Trailing 3-dot overflow action menu for instant rename, bookmark, tag, or export commands.

### 3. BottomNavigationBar & Navigation Rails
- **Mobile Container:** 80dp total height with safety inset, `#FFFFFF` surface with a 1px top border (`#E2E8F0`).
- **Active Indicator:** Material 3 pill shape (64×32dp) wrapped in `#E2E8F0` (neutral tint) or `#EFF6FF` (active blue tint) with active icon in `#2563EB`. Inactive icons remain neutral `#64748B`.

### 4. Category & Filter Chips
- **Container:** 36dp height, pill shape, default background `#F1F5F9` with no border.
- **Active State:** Background `#1E293B`, text color `#FFFFFF`.
- **Count Badge:** Circular secondary container (`#E2E8F0` on inactive, `#334155` on active) holding item count in `label-sm`.

### 5. Floating Reader Bottom Toolbar
- **Container:** Elevated capsule pill (`border-radius: 9999px`) pinned 24dp above the screen bottom, centered horizontally with an auto-hide behavior on scroll.
- **Specs:** 52dp height, `#FFFFFF` with 94% opacity blur, 1px border `#CBD5E1`, holding reading mode buttons: Table of Contents, Night/Warm reading toggle, Page Slider quick-trigger, and Bookmark toggle.

### 6. Progress Sliders (Reading Scrub Bar)
- **Track:** 4dp continuous bar in `#E2E8F0`. Active track spans in primary `#2563EB`.
- **Thumb:** 16dp circular `#FFFFFF` knob with a 2dp `#2563EB` ring border.
- **Floating Tooltip:** Displays `p. {current} / {total}` in `mono-metadata` centered above thumb during active drag.

### 7. Form Inputs & Search Fields
- **Container:** 48dp height, rounded 10dp, background `#F1F5F9`, borderless until focused.
- **Focus State:** 1.5px solid border in `#2563EB` with `#FFFFFF` background fill.
- **Trailing Action:** Clear text button (subtle slate cross) and optional format filter dropdown.

### 8. Checkboxes & Radio Selection
- **Form Factor:** 20×20dp box with 6dp corner radius for selection in document batch management.
- **Checked State:** Solid `#2563EB` fill with clean white interior checkmark vector.
