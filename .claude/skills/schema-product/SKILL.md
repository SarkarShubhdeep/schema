---
name: schema-product
description: Product, design and engineering rules for Schema, the native SwiftUI task and notes app for macOS and iPhone. Use before designing, building or reviewing any Schema feature, when writing or picking up a Schema GitHub issue, and when running a Schema health audit.
---

# Schema product rules

Schema is a keyboard-first task and notes app: to-do list pages, scratchpad pages, a Today dashboard, quick capture, and a GitHub inbox for review requests and mentions. It should feel quiet, fast and familiar: native macOS and iOS behaviour, with Schema's own type, color and shapes on top.

## Sources of truth
- Design system: https://claude.ai/artifact/5fDFJNPDcbr1nWJwyGSG9L (tokens, type, components, README rules).
- Screens: the Schema Dashboard canvas, https://claude.ai/artifact/Tc231A32d5yW9ouRySCyC5.
- What to borrow from Notion, Linear and GitHub: `references/products.md`.
- Health audit checklist: `references/audit.md`.

## Workflow
1. **Design before code.** Any new screen or visible change is designed on the canvas and approved before it is coded. If an issue needs a design decision that isn't on the canvas, stop and ask.
2. **One issue, one branch, one PR.** Branch off `main` as `feature/<n>-<slug>` or `fix/<n>-<slug>`. The PR closes the issue and says what changed and what to check.
3. **Build clean.** Zero warnings, then launch the app so the change can be seen. Never claim something works without running it.
4. **Screenshots for visual changes.** Launch the Debug build with `-SchemaDemoData` (sample data in memory, never the user's real tasks; add `-SchemaDemoDark` for dark mode, since `-AppleInterfaceStyle` stops the window from opening) and capture only the Schema window with `screencapture -l <window id>`, never the whole screen. Save them as `docs/screenshots/<issue>/<name>.png` in the PR branch and embed them in the PR body via a commit-SHA raw URL.
5. **Stop after each PR.** Tell the user the PR is ready and wait. The user merges manually; start the next issue only after that, from an updated `main`.
6. **Stay in scope.** Unrelated improvements go into a new issue, not the current PR.

## Design rules (from the user's feedback)
- Neutral greys everywhere; yellow (`#f5c518`) only for one primary action per view. Never yellow checkboxes, progress or selection.
- Space Grotesk for titles, numbers, times, counts, badges and labels; Satoshi for task titles, body text and controls.
- Shapes: things you press are fully rounded pills or circles; containers, cards and dialogs use 12–16px corners; small static labels use 6–8px.
- Quiet states: a done task is a plain grey check with a struck-through title; selection is a soft grey background, never a hard outline.
- Short values never wrap ("3:00 PM" stays on one line). Shorten the neighbouring text instead.
- Horizontal scrolling shows no scrollbar or arrow buttons, only an edge fade.
- Icon-only buttons get a hover tooltip with name and shortcut. No permanent labels, onboarding popups or extra prompts.
- Don't copy Google Material's signature looks: no wavy progress bars, no joined button groups that change shape, no decorative check shapes.
- On iPhone use current native patterns (floating collapsible tab bar, native sheets, swipe actions); on iPad, a sidebar.

## Engineering rules
- SwiftUI and SwiftData only; no third-party frameworks without asking.
- Every model change ships a new `VersionedSchema` and migration stage; never lose user data.
- Keep views small: split anything that grows past ~400 lines or ~8 `@State` values; shared UI state lives in `@Observable` objects.
- Fix focus and layout properly; no `DispatchQueue.main.async` hacks.
- Lists must stay smooth with 1,000+ tasks: query only what a view shows, keep stable sort keys.
- Use the installed skills: `swiftui-pro` when writing or reviewing views, `swiftdata-pro` for models and migrations, `swift-concurrency` for async work, `swiftui-performance-audit` for slow screens.
- Keyboard first: every primary action has a shortcut and works without the mouse.

## Writing issues
Title in sentence case, then 2–3 lines: what will be done and what it achieves. Link the canvas board when there is one.
