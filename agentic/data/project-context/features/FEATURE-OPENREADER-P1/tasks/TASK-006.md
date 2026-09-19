# Engineering Task

## Status
DONE (commit `c9faa36`)

## Story
Settings

## Objective
Give the user control over theme, the local index, and cache, plus a privacy statement (BRD 9.18; ODF-027/028/029).

## Scope
`SettingsController`/`SettingsView`, wraps existing `ThemeController` rather than reimplementing theming.

## Dependencies
TASK-001 (refresh index), TASK-003 (clear recent history).

## Implementation Requirements
- Theme section is `RadioGroup<ThemeMode>` (migrated off the deprecated `RadioListTile.groupValue`/`onChanged` API during this task).
- "Refresh file index" calls `rescan()` and reports a count; "Clear cache" deletes the temp directory's contents only.
- Reader preferences (BRD 9.18 "Reader" section) are intentionally absent — they configure reader screens that don't exist yet; adding them now would be dead UI.

## Acceptance Criteria
- Theme changes persist across restart (existing `AppSettingsRepository` behavior, unchanged).
- Clear cache/clear recents never touch original documents (see TASK-003/TECH-SPEC Security note).

## Test Requirements
**Not met.**

## References
- `SRS.md` ODF-027/028/029

## Out of Scope
Reader preference settings — deferred until a reader exists (Phase 2/3).
