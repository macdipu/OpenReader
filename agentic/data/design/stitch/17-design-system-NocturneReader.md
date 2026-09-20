---
name: Nocturne Reader
colors:
  surface: '#0f131c'
  surface-dim: '#0f131c'
  surface-bright: '#353943'
  surface-container-lowest: '#0a0e17'
  surface-container-low: '#181b25'
  surface-container: '#1c1f29'
  surface-container-high: '#262a34'
  surface-container-highest: '#31353f'
  on-surface: '#dfe2ef'
  on-surface-variant: '#bdc8d1'
  inverse-surface: '#dfe2ef'
  inverse-on-surface: '#2c303a'
  outline: '#87929a'
  outline-variant: '#3e484f'
  surface-tint: '#7bd0ff'
  primary: '#8ed5ff'
  on-primary: '#00354a'
  primary-container: '#38bdf8'
  on-primary-container: '#004965'
  inverse-primary: '#00668a'
  secondary: '#bdc2ff'
  on-secondary: '#131e8c'
  secondary-container: '#2f3aa3'
  on-secondary-container: '#a8afff'
  tertiary: '#4ee6aa'
  on-tertiary: '#003825'
  tertiary-container: '#22c990'
  on-tertiary-container: '#004e35'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c4e7ff'
  primary-fixed-dim: '#7bd0ff'
  on-primary-fixed: '#001e2c'
  on-primary-fixed-variant: '#004c69'
  secondary-fixed: '#e0e0ff'
  secondary-fixed-dim: '#bdc2ff'
  on-secondary-fixed: '#000767'
  on-secondary-fixed-variant: '#2f3aa3'
  tertiary-fixed: '#68fcbf'
  tertiary-fixed-dim: '#45dfa4'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005137'
  background: '#0f131c'
  on-background: '#dfe2ef'
  surface-variant: '#31353f'
typography:
  display-lg:
    fontFamily: Space Grotesk
    fontSize: 3.5rem
    fontWeight: '700'
    lineHeight: 4rem
    letterSpacing: -0.03em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 2.25rem
    fontWeight: '600'
    lineHeight: 2.75rem
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 1.75rem
    fontWeight: '600'
    lineHeight: 2.25rem
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: 2rem
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 1.25rem
    fontWeight: '500'
    lineHeight: 1.75rem
  body-lg:
    fontFamily: Inter
    fontSize: 1.125rem
    fontWeight: '400'
    lineHeight: 1.875rem
    letterSpacing: 0.01em
  body-md:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.65rem
  body-sm:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.375rem
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 0.8125rem
    fontWeight: '500'
    lineHeight: 1.25rem
    letterSpacing: 0.03em
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 0.6875rem
    fontWeight: '500'
    lineHeight: 1rem
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1.25rem
  gutter-mobile: 0.75rem
  margin: 2rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system is engineered for deep focus, long-form night reading, and extreme power efficiency on OLED/AMOLED displays. The personality is utilitarian, architectural, and serene—evoking the atmosphere of an illuminated flight deck or an astronomical observatory.

The aesthetic fuses **True AMOLED Minimalism** with **Tactile Luminescence**. Visual noise is eliminated by anchoring canvas areas to pure `#000000`, while interface surfaces float through nuanced, deep-space elevation steps. Accents do not shout; they function as precision indicators—subtle chromatic beacons that identify document types instantly while preserving dark adaptation and eliminating night-time eye fatigue.

## Colors

The palette leverages a strict hierarchy of deep space surfaces, low-glare slate typography, and functional chromatic identifiers.

### Color Tiers
- **Base Canvas (`#000000`)**: Pure physical off-pixel black for maximum battery conservation and infinite contrast.
- **Surface Elevation 1 (`#0a0e17`)**: Midnight void for structural containers, side rails, and navigation bars.
- **Surface Elevation 2 (`#121824`)**: Elevated cards, toolbars, reader overlays, and dialogs.
- **Borders & Dividers**:
  - `border-subtle`: `#1e293b` (structural frames, divider lines, inset strokes).
  - `border-focus`: `#334155` (interactive state boundaries, hover states).

### Text & Glyphs
- **Primary Text (`#f1f5f9`)**: Soft frost white, tuned down from harsh 100% white to eliminate halo effects and retina strain in pitch-black rooms.
- **Secondary Text (`#94a3b8`)**: Cool slate grey for secondary metadata, tool labels, and secondary UI.
- **Tertiary / Muted Text (`#64748b`)**: Deep slate for disabled states, page counters, and timestamps.

### Document Type Accents (Luminescent Tokens)
- **PDF Accent (`#38bdf8`)**: Electric Sky Blue for documents, read progress, and annotation pins.
- **Sheet Accent (`#34d399`)**: Emerald Mint for spreadsheets, data tables, and calculation summaries.
- **Doc Accent (`#818cf8`)**: Soft Indigo / Violet for rich text documents, notes, and bookmark ribbons.
- **Slide Accent (`#fb923c`)**: Amber Coral for presentation decks, highlights, and media playback cues.

## Typography

Typography prioritizes optical clarity in zero-lux environments. High-density body text relies on **Inter**, tuned with open apertures, generous line heights (1.65x–1.85x), and fractional positive letter tracking to completely negate character bleeding against pitch-black backgrounds.

Headlines employ **Space Grotesk** to inject a clean, technical edge suited for modern reader tooling and file management. Monospaced metadata, metrics, page indices, and document technical specifications are rendered in **JetBrains Mono** to reinforce precision and systematic layout stability.

## Layout & Spacing

The layout model is anchored by a structured fluid grid optimized for adaptive reading panels, side drawers, and HUD-style document toolbars.

- **Breakpoints**:
  - `mobile`: `< 768px` (single-column fluid feed, collapsible bottom sheets, 1rem margin).
  - `tablet`: `768px – 1199px` (2-column layout, docked reading canvas + collapsible index rail).
  - `desktop`: `≥ 1200px` (multi-column structured workbench, 3-panel split view: outline/inspector, document viewport, tools).

Spacing strictly follows an 8pt architectural rhythm, with 4pt (`space-xs`) reserved for tight tool groupings and micro-indicators. Large spatial margins (`space-xl`) isolate the active document page from UI chrome, reinforcing immersion.

## Elevation & Depth

Shadows do not exist in pure pitch-black space; traditional diffuse drop shadows create muddy grey halos that destroy true AMOLED black points. Visual depth is established exclusively through **Tonal Surface Stacking**, **Hairline Perimeter Borders**, and **Controlled Chromatic Glows**.

1. **Surface 0 (Canvas)**: `#000000` (OLED zero-power ground).
2. **Surface 1 (Panels & Toolbars)**: `#0a0e17` framed by a 1px solid stroke of `#1e293b`.
3. **Surface 2 (Popovers, Modals, Cards)**: `#121824` framed by a 1px solid stroke of `#334155`.
4. **Active/Focus States (Luminescent Flare)**: Interactive nodes leverage an ultra-subtle optical aura rather than an offset shadow: `box-shadow: 0 0 16px -2px rgba(accent_rgb, 0.25)`.
5. **Backdrop Blurs**: Floating glass HUDs use `background: rgba(10, 14, 23, 0.85)` with `backdrop-filter: blur(12px)` over document canvases to maintain spatial context without blocking peripheral content.

## Shapes

The design system adopts a **Soft (Level 1)** geometry (`0.25rem` / 4px base radius; `0.5rem` / 8px for containers; `0.75rem` / 12px for modal cards). This subtle corner radius softens industrial lines without entering bubbly or casual territory, maintaining the sleek, technical feel of a dedicated reading terminal. Circular shapes are reserved strictly for floating circular action buttons and status beacons.

## Components

### Buttons
- **Primary**: Background `#121824`, border 1px solid `var(--accent)`, text `#f1f5f9`. On hover, trigger a low-intensity radial glow: `box-shadow: 0 0 12px -2px rgba(var(--accent-rgb), 0.35)`.
- **Secondary / Ghost**: Background transparent, border 1px solid `#1e293b`, text `#94a3b8`. On hover, border shifts to `#334155` and text to `#f1f5f9`.
- **Icon Actions**: 36x36px bounding box, text `#94a3b8`, transitions to `#f1f5f9` on hover with a `#121824` background pill.

### Chips & Badges
- **Format Indicators**: Height 22px, padding `0 8px`, font `label-sm`. Background `rgba(accent_color, 0.1)`, border 1px solid `rgba(accent_color, 0.25)`, text `accent_color`.
- **Tag / Status Chips**: Background `#0a0e17`, border 1px solid `#1e293b`, text `#94a3b8`.

### Lists & Document Rows
- Minimal row height: 56px.
- Background defaults to `#000000`. On hover, transition seamlessly to `#0a0e17` with a 1px left accent border corresponding to the file extension color (e.g., `#38bdf8` for PDF).
- Dividers are 1px solid `#1e293b`.

### Checkboxes & Radios
- Size: 18x18px.
- Unchecked: Background `#0a0e17`, border 1px solid `#334155`.
- Checked: Background `var(--primary_color_hex)`, border 1px solid `var(--primary_color_hex)`. Glyph is sharp `#000000`.

### Input Fields
- Background: `#0a0e17`.
- Border: 1px solid `#1e293b`. Text: `#f1f5f9`. Placeholder: `#64748b`.
- Active/Focused: Border 1px solid `#38bdf8`, box-shadow `0 0 8px rgba(56, 189, 248, 0.2)`.

### Cards & Reading Panes
- Background: `#0a0e17`.
- Border: 1px solid `#1e293b`.
- Reading Viewport: Framed against `#000000` with an option for 0% glare inverted render styles.

### Reader HUD (System-Specific Component)
- Docked floating toolbar at the bottom or top of viewport.
- Background: `rgba(10, 14, 23, 0.88)` with `backdrop-filter: blur(16px)`.
- Enclosed with a crisp 1px border (`#1e293b`), hosting page scrubbers, document zoom, night brightness sliders, and annotation toggles with tactile feedback.
