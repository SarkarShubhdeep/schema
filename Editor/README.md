# Schema editor

The page editor is [TipTap](https://tiptap.dev) (on ProseMirror), running in a
`WKWebView` inside the app. This folder holds its source and build setup; the
app ships only the bundled result in `Schema/Resources/Editor/`.

## Build

```bash
cd Editor
npm ci
npm run build
```

`npm run build` writes `Schema/Resources/Editor/editor.js`. Commit that file:
Xcode builds never run npm.

## Supply chain

- Exact versions only, with `package-lock.json` holding an integrity hash for
  every package. Use `npm ci`, never `npm install`, unless you mean to upgrade.
- `.npmrc` turns install scripts off.
- Upgrade on purpose: pick a release that has been out for at least two
  weeks, run `npm audit`, rebuild, and review the `editor.js` diff in the PR.
- The editor page has a content-security policy that blocks the network, and
  uses only TipTap's MIT-licensed open-source extensions.

## Bridge

Swift talks to the page through `window.schemaEditor` (`setContent`,
`setMarkdown`, `getJSON`, `getMarkdown`, `focus`). The page answers through the
`schema` message handler with `ready`, `change`, `loaded`, `escape`, `focus`
and `error`. See `src/editor.js` and `Schema/Core/Editor/TipTapBridge.swift`.

## Documents

Each page and task body is stored as TipTap JSON (schema V7, #77). Every
document is shown with a key (the page's or task's id); a change comes back
with the key it was made in, so typing just before switching pages is saved
to the right page, and a new key starts a fresh undo history. A to-do made
into a task carries the task's id in its `taskId` attribute.
