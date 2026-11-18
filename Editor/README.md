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

## Feel check

Debug builds launched with `-SchemaEditorFeelCheck` show a scratchpad in the
v0.5 editor and in TipTap side by side. TipTap's edits are not saved there.
