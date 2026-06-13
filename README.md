# Schema

A lightning-fast, keyboard-driven multi-list task manager for macOS.

## v0.1 Features

- Multiple task lists with horizontal tab navigation
- Rapid keyboard task entry (`n` to focus, `Enter` to save)
- List switching via `Cmd+1` through `Cmd+9`
- SwiftData persistence
- Optional task reminders via macOS notifications

## Requirements

- macOS 14.0+
- Xcode 15.0+

## Architecture

- **UI:** SwiftUI (macOS-specific views in `Schema/macOS/`)
- **Storage:** SwiftData
- **Pattern:** MVVM with platform-agnostic core logic in `Schema/Core/`

## Branching

- `main` — production-ready releases
- `develop` — integration branch
- `feature/*` — feature work
- `enhancement/*` — improvements and polish
