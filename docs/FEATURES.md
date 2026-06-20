# Feature Tracker

Living document for what Schema has shipped, what is in progress, and what still needs work. Use this alongside the release docs when planning the next slice of work.

| Document | Role |
|----------|------|
| [CHANGELOG.md](../CHANGELOG.md) | What shipped in each release |
| [KNOWN_ISSUES.md](KNOWN_ISSUES.md) | Current limitations and known bugs |
| [V0.2_ROADMAP.md](V0.2_ROADMAP.md) | Phased implementation plan for v0.2 |

**Integration branch:** `develop`  
**Active branch:** `feature/task-detail-view`  
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
- [x] Detailed task view sheet (Return or double-click) — v0.2, `feature/task-detail-view`
- [x] Edit title, description, and reminder in detail sheet — v0.2

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
| | | |

---

## Needs work

Gaps, partial implementations, and planned v0.2 items. See [V0.2_ROADMAP.md](V0.2_ROADMAP.md) for phase order and file touch points.

### Next up (after Phase 1 merges)

- [ ] SwiftData `VersionedSchema` + migration plan (Phase 0 — required before drag-reorder)

### Foundation

- [ ] Recoverable error UI when `ModelContainer` fails (replace `fatalError`)

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

- **Phase 1 (detail view):** implemented on `feature/task-detail-view` — merge to `develop` after UI polish and smoke test.
- **iOS:** no work until v1.0.
