# Known Issues — v0.1

This document lists intentional limitations and known bugs in Schema v0.1. Items here are expected behavior for this release, not surprises.

**v0.2 targets:** [V0.2_ROADMAP.md](V0.2_ROADMAP.md)

## Features not yet implemented

### Task descriptions

- `SchemaTask` supports a `taskDescription` field in the data model.
- There is **no UI** to create or edit descriptions. Descriptions are display-only when present.

### Manual sort / drag-to-reorder

- The "Manual" sort option orders tasks by **creation date** (oldest first).
- True drag-to-reorder is not implemented.

### List reordering

- `ListViewModel.reorderLists()` exists but is **not wired** to any view. List tab order cannot be changed by the user.

## Data & migration

### No SwiftData migration plan

- v0.1 uses a default local SwiftData store with no `VersionedSchema` or migration stages.
- Fresh installs work fine. **Schema changes in future updates may require deleting and reinstalling** until migration is implemented.

### iOS

- App Store Connect lists iOS and macOS, but **no iOS app exists yet**. Only macOS builds are distributed for v0.1.

## Other

### Error handling

- `ModelContainer` creation failure calls `fatalError` (app will crash on launch if the store is corrupted).
- Save and reminder failures log via `assertionFailure` in debug builds only.

### App Store name

- The App Store listing name is **Schema: Fast, Simple Todos** because "Schema" alone is taken globally. The in-app name remains **Schema**.
