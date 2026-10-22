# ADR-OPENREADER-desktop-drop: Drag-and-drop to open files on desktop

## Status
Accepted (2026-10-22): technical approval of CR-OPENREADER-UX Phase 3, UX-34.

## Context
- **The request.** Desktop builds (Windows, macOS, Linux) can open a file only through the nav-rail "Open file" picker or a command-line argument. The user chose drag-and-drop onto the window as part of UX-34, knowing it needs a new dependency.
- **Why a dependency.** Flutter has no built-in way to receive OS file drops on desktop; it needs a platform plugin.
- **The rule it breaks.** The project's phase rule (FEATURE-OPENREADER-P5) is "no new dependency, no ADR". This ADR is the explicit exception.

## Decision
- **Package.** Add `desktop_drop` (0.4.4, Apache-2.0, MixinNetwork/flutter-plugins, already in the local pub cache).
- **Where.** Wrap the app shell in its `DropTarget` on desktop platforms only (`PlatformInfo.isDesktop`). On Android the widget is not built.
- **Handling a drop.**
  - Take the first dropped file path and hand it to the existing `IncomingIntentService.handlePath`. That is the same path as the "Open file" picker and command-line launch, so supported-format checks, error messages and reader routing are reused.
  - Show a highlighted drop overlay while a drag is over the window.
  - Ignore extra files and say so ("Opened the first file").
- **No new permissions** and no network use.

## Alternatives
- **`super_drag_and_drop`.** It's more capable (rich data, drag out), but heavier: a Rust toolchain and native build steps. Out of proportion for a single drop target.
- **A custom platform channel per OS.** That's three native implementations to maintain, which is more risk than one well-used plugin.
- **No drag-and-drop.** The picker and Ctrl/Cmd+O cover the need. The user explicitly chose to include drag-and-drop.

## Consequences
- **One new runtime dependency**, desktop-only in behaviour. It adds native plugin registration for Windows, macOS and Linux to their generated plugin files.
- **Releases.** The release workflow's desktop builds compile the plugin, and each OS build must be verified on its own OS.
- **Tests.** The drop handler is tested at the controller level by calling the handler with paths. The native drop itself can't be unit-tested.
- **Drops while a reader is open.** A drop opens the file on top of the current reader, with no overlay shown, because the drop target wraps the shell. This was accepted at release 1.0.6.

## Risks
- **Plugin maintenance.** If it stops building on a new Flutter version, the drop target can be removed without affecting anything else, because drops reuse the existing open path.
- **macOS sandbox.** Dropped files must be readable under the app's sandbox entitlements. This is to be verified on a macOS build. If not, the entitlement for user-selected or dropped files needs review.
- **Linux.** Desktop environments differ in drag-and-drop behaviour. To be verified on a Linux build.
