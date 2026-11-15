# What Schema borrows from Notion, Linear and GitHub

Sourced from the official docs on 2026-11-15. Borrow the interaction pattern, not the look. Re-check a page before relying on a detail for a build.

## Notion: pages and the scratchpad (Milestone 2)
- Content is a tree of typed blocks (paragraph, heading, to-do, quote, divider, child page). Only some block types hold children. Model scratchpad pages as an ordered block tree with a per-type "can have children" flag. [Block reference](https://developers.notion.com/reference/block)
- `/` opens a block menu that filters as you type; the `+` in the margin opens the same menu. [Writing and editing basics](https://www.notion.com/help/writing-and-editing-basics)
- Markdown shortcuts at line start: `#` `##` `###` + space, `-` + space, `[]` for a to-do, `>` for a quote, `---` for a divider; `**bold**` and `` `code` `` inline. [Keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts)
- Turn into: change a block's type in place (⌘/), including turning a line into a page. Same page.
- Tab / ⇧Tab nest and un-nest blocks; ⌘⇧↑↓ moves a block; Esc selects the block being edited. Same page.
- A page block creates a subpage; an `@` mention only links and creates a backlink. [Links and backlinks](https://www.notion.com/help/create-links-and-backlinks)
- Notion has no quick-note capture, only a web clipper that asks for a destination. Schema's ⌃⌥N quick note goes further. [Web clipper](https://www.notion.com/help/web-clipper)
- Avoid what slows Notion: huge collections, many visible properties, sorting on text or formulas, many inline databases on one page. Keep stable explicit sort keys. [Database performance](https://www.notion.com/help/optimize-database-load-times-and-performance), [Intro to databases](https://www.notion.com/help/intro-to-databases)

## Linear: speed, keyboard and labels
- Principles: build for the people doing the work, purpose-built, say no to busy work, simple first then powerful, decide and move on, plain words with no invented jargon. [Linear Method](https://linear.app/method/introduction)
- One key creates (Linear: `C`; Schema: `N`). A new item needs only a title. Esc keeps a draft. [Creating issues](https://linear.app/docs/creating-issues)
- Command menu with scoped prefixes; `/` for quick search, ⌘F to find in the current view. [Search](https://linear.app/docs/search)
- Label groups (Milestone 2+): one level of nesting, labels in a group are mutually exclusive. [Label groups](https://linear.app/changelog/2022-11-10-label-groups)
- Sub-items: a pasted checklist becomes sub-items; some fields are inherited and labels are not. [Parent and sub-issues](https://linear.app/docs/parent-and-sub-issues)
- Inbox is fully keyboard driven: J/K move, U read/unread, H snooze, Backspace remove, a Priority tab for what needs attention. [Inbox](https://linear.app/docs/inbox), [Notifications](https://linear.app/docs/notifications)
- Quality as a habit: fix small papercuts every week; keep animation timing consistent across similar elements. [Quality Wednesdays](https://linear.app/now/quality-wednesdays)

## GitHub: the inbox (Milestone 3)
Schema is a quick notifier and responder only: read, reply, approve, request changes, mark done. Never diffs, file trees or code checkout.

- Notification reasons: `review_requested`, `mention`, `team_mention`, `author`, `comment`, `assign`, `state_change`, `subscribed`, `manual`, `ci_activity`. [Notifications API](https://docs.github.com/en/rest/activity/notifications)
- Inbox states mirror GitHub: unread/read, Done, Saved. Shortcuts to mirror: `E` done, ⇧U unread, ⇧I read. [About notifications](https://docs.github.com/en/subscriptions-and-notifications/concepts/about-notifications), [Keyboard shortcuts](https://docs.github.com/en/get-started/accessibility/keyboard-shortcuts)

| Need | Endpoint | Permission |
| --- | --- | --- |
| List notifications | `GET /notifications` (`participating`, `since`, `per_page` ≤ 50) | Classic token `notifications` or `repo`; fine-grained tokens are not listed |
| Mark read / done | `PATCH` / `DELETE /notifications/threads/{id}` | same |
| Review a PR | `POST /repos/{o}/{r}/pulls/{n}/reviews` with `APPROVE`, `REQUEST_CHANGES` or `COMMENT` (body required for the last two) | Pull requests: write |
| Comment on a PR or issue | `POST /repos/{o}/{r}/issues/{n}/comments` | Issues: write |
| Open review requests | `GET /search/issues?q=is:pr is:open user-review-requested:@me` (30/min) | read |

- Sign-in: OAuth device flow (`POST github.com/login/device/code`, user enters the code, poll `login/oauth/access_token`; on `slow_down` add 5s). [Authorizing OAuth apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps)
- Polling: send `If-Modified-Since`, never poll faster than `X-Poll-Interval`, one request at a time, at least 1s between writes, back off on 403/429 using `retry-after`. 304s are free. [Best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api), [Rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- Open decision for Milestone 3: the notifications API only accepts classic tokens or OAuth, not fine-grained tokens. Prefer OAuth device flow.
