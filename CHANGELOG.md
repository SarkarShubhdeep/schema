# Changelog

All notable changes to Schema are documented in this file.

## [Unreleased]

## [0.2.0] — 2026-06-21

### Added

- Detailed task view sheet — open with Return or double-click on a selected task
- Edit task title, description, reminder, routine schedule, and sequence order in the detail sheet
- Routine tasks with daily sequencing and ordered completion chains
- Drag-to-reorder tasks when sort is Manual (`manualSortIndex` persisted per list)
- Inline `@` mentions in quick add and task title — assign list, time, date (`@tomorrow`, `@3pm`, `@ListName`)
- List suggestion picker with keyboard ↑/↓ when multiple lists match
- Native settings layout with Notifications, Default List, and Routine sections
- Setting to complete follower routine tasks without finishing the parent first
- All Lists context menu — rename, change color, delete
- SwiftData versioned schema (V1–V4) with migration plan for upgrades from v0.1
- Recoverable launch screen when the local store fails (Retry / Reset Data)

### Changed

- Return on a selected task opens the detail sheet (replaces inline title editing)
- Settings uses divider-based sections instead of card-style group boxes

### Fixed

- Task row checkbox clicks no longer blocked by list click handler
- Double-click to open task detail works reliably after checkbox interaction

## [0.1.0] — 2026-06-14

### Added

- Multiple task lists with horizontal tab navigation
- Rapid keyboard task entry (`n` to focus, `Enter` to save)
- List switching via `Cmd+1` through `Cmd+9`
- SwiftData persistence for lists and tasks
- Optional task reminders via macOS notifications
- Everything view aggregating tasks across all lists
- All Lists grid overview
- Sort and filter preferences (persisted across launches)
- Default writable list setting for Everything view
- Undo for task actions (`Cmd+Z`)
- Internal TestFlight distribution (macOS)

### Known limitations

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for the full v0.1 limitation list.
