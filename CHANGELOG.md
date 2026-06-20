# Changelog

All notable changes to Schema are documented in this file.

## [Unreleased]

Planned for **v0.2.0** — see [docs/V0.2_ROADMAP.md](docs/V0.2_ROADMAP.md).

### Added

- Detailed task view sheet — open with Return or double-click on a selected task
- Edit task title, description, and reminder in the detail sheet

### Changed

- Return on a selected task opens the detail sheet (replaces inline title editing)

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
