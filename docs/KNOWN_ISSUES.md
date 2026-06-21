# Known Issues — v0.1

This document lists intentional limitations and known bugs in Schema v0.1. Items here are expected behavior for this release, not surprises.

**v0.2 targets:** [V0.2_ROADMAP.md](V0.2_ROADMAP.md)

## Features not yet implemented

### Manual sort / drag-to-reorder

- The "Manual" sort option orders tasks by **creation date** (oldest first).
- True drag-to-reorder is not implemented.

### List reordering

- `ListViewModel.reorderLists()` exists but is **not wired** to any view. List tab order cannot be changed by the user.

## Data & migration

### SwiftData migration plan

- Schema versions V1–V4 are defined in `Schema/Core/Persistence/SchemaMigrationPlan.swift`.
- Upgrades from v0.1 stores run lightweight stages for list colors and routine fields, then backfill `manualSortIndex` on V4.
- If the store cannot be opened, the app shows a recoverable error screen (Retry / Reset Data) instead of crashing.

### iOS

- App Store Connect lists iOS and macOS, but **no iOS app exists yet**. iOS is deferred to **v1.0**; only macOS builds are distributed for v0.x.

## Other

### Error handling

- Save and reminder failures log via `assertionFailure` in debug builds only.

### App Store name

- The App Store listing name is **Schema: Fast, Simple Todos** because "Schema" alone is taken globally. The in-app name remains **Schema**.
