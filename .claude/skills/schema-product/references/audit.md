# Schema health audit

Run at the end of every milestone and every few issues. Report findings as a short table (area, finding, severity, proposed issue). Do not fix during the audit; each finding becomes an issue.

## 1. Build and code health
- `xcodebuild` Debug and Release: zero warnings. Note any new warnings since the last audit.
- Run the `swiftui-pro` review on views changed since the last audit (only the relevant reference files).
- Run `swiftdata-pro` on models, migrations and queries; confirm every schema change has a VersionedSchema and a migration stage.
- Run `swift-concurrency` on any `Task {}`, `DispatchQueue`, `@MainActor` or `Sendable` changes. No new `DispatchQueue.main.async` used to fix focus or layout timing.
- Files over ~400 lines or views with more than ~8 `@State` values: flag for splitting.

## 2. Performance
- Use `swiftui-performance-audit` for the task list, Today and any screen with a long list.
- Check with 1,000 tasks across 20 pages: launch to first frame, switching pages, scrolling, completing a task, drag-to-reorder. Anything that visibly stutters is a finding.
- `@Query` usage: no view should fetch all tasks when it shows one page.

## 3. Window sizes and devices
- Mac: 880, 1100 and 1440px wide, and the minimum window size. Panels collapse at the documented breakpoints; nothing clips or wraps badly.
- iPhone (once it exists): smallest and largest current iPhone, and iPad split view.
- Short values never wrap ("3:00 PM" stays on one line).

## 4. Light, dark and accessibility
- Both themes on every screen. Text contrast 4.5:1 (3:1 for 24px+ and for borders/icons that carry meaning).
- VoiceOver: every icon-only control has a label; rows read title, state and time in a sensible order.
- Keyboard: every primary action reachable without the mouse; focus is always visible.
- Dynamic Type on iPhone; Reduce Motion respected.

## 5. Product consistency
- Compare changed screens against the design system and canvas: one yellow action per view, quiet checks, subtle selection, pills for actions, 12–16px containers.
- No new settings, prompts or onboarding added without a design.
