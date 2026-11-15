# Changelog

All notable changes to Schema are documented in this file.

## [Unreleased]

### Changed

- New color tokens from the Schema design system: neutral greys with a single yellow accent, in light and dark (#6).
- Lists no longer have their own colors; tabs, tags and list cards are neutral. The Change Color menu is gone.
- Bundled Space Grotesk (titles, numbers, times, counts, badges) and Satoshi (task titles, body text, buttons), with the design system's type styles (#7).

## [0.3.0] — 2026-11-12

### Fixed

- Task rows no longer squish or scroll out of view when switching list tabs (#1). The task list now uses a plain `ScrollView` instead of `List`, and each list opens scrolled to the top.
- Drag-to-reorder works while Schema is the active window (#3). Rows are dragged with a SwiftUI gesture, and an accent line shows where the task will land.
- Reordering in the Everything view or with a filter active drops tasks where you release them instead of jumping inside their own list (#3).
- Dragging while a non-Manual sort is active keeps the on-screen order when the list switches to Manual.

### Changed

- Dragging the first task of a routine chain moves the whole chain; drops never split a chain.
- Arrow-key selection scrolls only as far as needed instead of re-centering on every press.
- Internal: `ContentView` split into `ContentView` (window root), `WorkspaceView` (layout), and `WorkspaceView+Actions`; selection, focus, and panel state moved into `WorkspaceState`. The AppKit mouse shim `ListRowMouseHandler` was removed.

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
