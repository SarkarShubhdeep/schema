# Schema

A lightning-fast, keyboard-driven multi-list task manager for macOS.

**App Store listing name:** Schema: Fast, Simple Todos  
**In-app name:** Schema

## Features

- Multiple task lists with horizontal tab navigation
- Rapid keyboard task entry (`n` to focus, `Enter` to save)
- List switching via `Cmd+1` through `Cmd+9`
- SwiftData persistence
- Optional task reminders via macOS notifications
- Drag-to-reorder, routine tasks with ordered chains, and a task detail panel
- Inline `@` mentions for list, date, and time
- Sort, filter, and default-list preferences (persisted across launches)

## Requirements

- macOS 14.0+
- Xcode 15.0+

## Internal testing (TestFlight)

Schema is distributed to internal testers via **TestFlight for Mac**.

1. Install [TestFlight for Mac](https://apps.apple.com/app/testflight/id899247664).
2. Accept the App Store Connect invite.
3. Install **Schema: Fast, Simple Todos** from TestFlight.

See [docs/INTERNAL_TESTING.md](docs/INTERNAL_TESTING.md) for the full testing guide, keyboard shortcuts, and bug report template.

## Build from source

```bash
git clone <repository-url>
cd Schema
open Schema.xcodeproj
```

Or build from the command line:

```bash
xcodebuild \
  -project Schema.xcodeproj \
  -scheme Schema \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## Documentation

| Document | Description |
|----------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [docs/INTERNAL_TESTING.md](docs/INTERNAL_TESTING.md) | TestFlight install and test checklist |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Current limitations |
| [docs/RELEASE.md](docs/RELEASE.md) | Archive, upload, and git tag workflow |
| [docs/PRIVACY.md](docs/PRIVACY.md) | Privacy policy |

## Feedback

Report bugs via GitHub Issues. Include the version from **Settings** (e.g. `0.1 (1)`), macOS version, and steps to reproduce.

## Architecture

- **UI:** SwiftUI (macOS-specific views in `Schema/macOS/`)
- **Storage:** SwiftData
- **Pattern:** MVVM with platform-agnostic core logic in `Schema/Core/`

## Branching

- `main` — production-ready releases (currently **v0.3.0**)
- `develop` — integration branch for upcoming work
- `feature/*` — feature work
- `enhancement/*` — improvements and polish
- `fix/*` — bug fixes

See [docs/V0.2_ROADMAP.md](docs/V0.2_ROADMAP.md) for the current v0.2 plan.
