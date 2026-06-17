# Feature Tracker

Living document for what Schema has shipped, what is in progress, and what still needs work. Use this alongside the release docs when planning the next slice of work.

| Document | Role |
|----------|------|
| [CHANGELOG.md](../CHANGELOG.md) | What shipped in each release |
| [KNOWN_ISSUES.md](KNOWN_ISSUES.md) | Current limitations and known bugs |
| [V0.2_ROADMAP.md](V0.2_ROADMAP.md) | Phased implementation plan for v0.2 |

**Integration branch:** `develop`  
**Current release:** v0.1.0 (macOS, TestFlight)

---

## How to use this doc

- Move items to **Developed** when they ship; note the version.
- Move items to **In progress** when a branch is open; add branch name or PR link.
- Add new ideas under **Backlog** — this section is yours to extend.
- When something lands, update [CHANGELOG.md](../CHANGELOG.md) and close or edit [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

---

## Developed

Features that exist in the current build.

### Lists & navigation

- [x] Multiple task lists with horizontal tab navigation
- [x] Everything view — tasks aggregated across all lists
- [x] All Lists grid overview
- [x] List switching via `Cmd+1` … `Cmd+9`, `Ctrl+Tab`, `/` for Everything
- [x] Create new list (`Cmd+N`)
- [x] Default writable list setting (Everything vs a specific list)

### Tasks

- [x] Create, complete, and delete tasks
- [x] Rapid keyboard entry (`n` → type → `Enter`)
- [x] Undo for task actions (`Cmd+Z`)
- [x] Optional task reminders via macOS notifications
- [x] `taskDescription` field on model (display-only when present)

### Preferences & persistence

- [x] SwiftData persistence for lists and tasks
- [x] Sort and filter preferences per list (persisted)
- [x] Default list color tags on seed data

### Distribution

- [x] macOS app (macOS 14+)
- [x] Internal TestFlight distribution

---

## In progress

_Work actively being built. Add branch or PR links as you go._

| Feature | Branch / PR | Notes |
|---------|-------------|-------|
| Detailed task view | `feature/task-detail-view` | Return or double-click on a selected task to open |

---

## Needs work

Gaps, partial implementations, and planned v0.2 items. See [V0.2_ROADMAP.md](V0.2_ROADMAP.md) for phase order and file touch points.

### Next up

- [ ] **Detailed task view** — Return or double-click opens a dedicated task detail UI (title, description, reminder, etc.)

### Foundation

- [ ] SwiftData `VersionedSchema` + migration plan (required before new `@Model` fields)
- [ ] Recoverable error UI when `ModelContainer` fails (replace `fatalError`)

### Task descriptions

- [ ] UI to create and edit task descriptions (`SchemaTask.taskDescription` exists; no editor today)

### Sorting & reordering

- [ ] True drag-to-reorder for tasks when sort = Manual (today sorts by `createdAt`)
- [ ] Persist task order field (likely new `order: Int` — needs migration)
- [ ] Wire `ListViewModel.reorderLists()` to UI (list tab / All Lists reorder)

### Reliability & polish

- [ ] Surface save failures to the user (today `assertionFailure` in debug only)
- [ ] Reminder scheduling error feedback when notification permission denied

---

## Backlog

_Ideas and future features — add yours below._

| Idea | Priority | Notes |
|------|----------|-------|
| | | |

---

## Out of scope (for now)

Items explicitly deferred unless promoted. From [V0.2_ROADMAP.md](V0.2_ROADMAP.md).

- **iOS app** — deferred to **v1.0** (App Store Connect lists iOS today; only macOS ships until then)
- Mac App Store public listing (TestFlight internal only for now)
- XCTest / CI pipeline
- App Store listing name change (stays **Schema: Fast, Simple Todos**)

---

## Notes

_Add planning notes, decisions, and open questions here._

- **v0.2 first slice:** detailed task view (`feature/task-detail-view`). Return currently inline-edits the task title; detail view will replace that behavior.
- **iOS:** no work until v1.0.
