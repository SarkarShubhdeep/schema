# Changelog

All notable changes to Schema are documented in this file.

## [Unreleased]

### Changed

- Pages now have a type, To-do list or Scratchpad, and can hold blocks (text, heading, bullet, to-do, quote, divider); tasks can hold blocks too, for their own page later (#36). The data migrates to schema V6 automatically and every existing page stays a to-do list. Nothing in the window changes yet.
- Added the first unit tests (Swift Testing, `SchemaTests` target): block ordering, page and block models, and the V5 → V6 migration. Tests run against an in-memory store, never the real one.

## [0.4.0] — 2026-11-15

The Mac redesign: a three-column window, the Schema design system (neutral greys, one yellow accent, Space Grotesk and Satoshi), sidebar navigation, redesigned to-do pages, a Today dashboard and an overview panel.

### Fixed

- Completed task titles and the sidebar's New page row now meet 4.5:1 text contrast in light and dark mode (#18).
- Setting a reminder could crash Schema, and then crash it again at every launch, when macOS refused to schedule the notification. Notification errors are now logged and the reminder time is still saved.

### Changed

- New color tokens from the Schema design system: neutral greys with a single yellow accent, in light and dark (#6).
- Lists no longer have their own colors; tabs, tags and list cards are neutral. The Change Color menu is gone.
- Bundled Space Grotesk (titles, numbers, times, counts, badges) and Satoshi (task titles, body text, buttons), with the design system's type styles (#7).
- Shared components in `Core/Design/Components`: pill buttons (primary, secondary, ghost, danger, ink), round icon buttons with tooltips, a quiet task checkbox, chips, count badges, key hints, section labels, cards and a flat progress bar (#8).
- Task rows, list tabs, the Add task bar, the Completed header and the New list and Rename dialogs now use these components. Press animations respect Reduce Motion (#4).
- Three-column window (#9): the title bar is hidden and the window controls sit at the top of a 240pt sidebar; the main column and a 300pt details panel each scroll on their own. Notifications and Settings (⌘,) moved from the toolbar into the sidebar header. Until panels can collapse, the window is at least 960pt wide.
- Side panels collapse to slim icon rails instead of hiding (#10): the sidebar to 72pt with ⌘⌥←, the details panel to 52pt with ⌘⌥→. Both are in the View menu, and Schema remembers each panel's state. The window can now narrow to 544pt.
- Side panels follow the window width (#11): 1200pt and wider shows both, 960–1199pt collapses the details panel, under 960pt collapses both. A panel you open or close by hand stays that way until the window crosses a breakpoint; opening one where both won't fit collapses the other.
- Sidebar navigation (#12): Views (Today, Upcoming, Everything) and Pages, with the active item as a dark pill and letter icons on the collapsed rail. Today lists tasks due today or overdue; Upcoming lists tasks due later (the dashboard versions come in #17). ⌘1–⌘9 now open pages, / opens Everything, and New page (⌘N) creates a to-do list. Collapsing the sidebar only changes its width: icons stay in place while labels clip and fade, section labels fade into dividers, and Notifications and Settings sit at the bottom in both states.
- The to-do page is redesigned (#13):
  - **Header:** a breadcrumb, sort pills (Manual, Due, A–Z) and a page-options menu, then a large title with the page type, its open count, and done-of-total with a progress bar.
  - **Quick add:** a full-width pill with a send button.
  - **Grouping:** open tasks are grouped into Today, Later this week, Later and Someday cards. Routine chains stay together.
  - **Drag to reorder:** drags stay inside a section.
  - **Completed:** completed tasks sit in a quiet collapsed card at the end.
  - The All Lists link and the List Preferences menu are gone; Filter now lives in page options.
- Selection toolbar (#14): selecting tasks shows a floating pill with the count, Reschedule (Today, Tomorrow, Next week, No date; keeps the time of day), Move to page, Delete, Complete (⇧↩) and Clear (Esc).
- Deleting tasks with the toolbar or ⌫ now asks once in a small dialog; Esc or a click outside cancels.
- Task details open in the right panel instead of a floating card (#15). The list stays visible beside them; the panel widens to 360pt while a task is open, even if it was collapsed, and returns to its saved state when closed. Delete in details now asks first, like the toolbar.
- The Routine switch no longer wraps letter by letter in the details panel; the weekdays sit on their own row.
- Removed the unused All Lists screen and the navigation container around the workspace.
- Tasks now record when they were completed (#16). The data migrates to schema V5 automatically; tasks completed before the update keep an empty completion date. This feeds Done today and the week chart (#17).
- Today is now a dashboard (#17): the date as title, tiles for Done today (with progress), Due today (with the next time) and This week, then today's tasks grouped by page. Today also counts routines that run today and tasks completed today.
- Upcoming lists future tasks grouped by day (Tomorrow, weekday, then date).
- Weeks start on Monday. Settings → Calendar → Week starts on can switch to Sunday; it applies to This week and the Later this week section.
- With no task open, the right panel shows an overview: the next four reminders, completions per day this week (today in yellow) and today's routines per page.

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
