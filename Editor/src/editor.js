// Schema's page editor: TipTap (ProseMirror) inside a WKWebView (#76).
//
// Bridge
//   Swift → JS: window.schemaEditor.setContent(json), .focus(where), .getJSON()
//   JS → Swift: webkit.messageHandlers.schema.postMessage({ type, ... })
//     ready   – the editor is mounted and can take content
//     change  – the document changed (debounced); carries json and plain text
//     loaded  – a document from setContent is on screen; carries ms
//     escape  – Esc pressed with nothing to close, so the app can take focus
//     focus   – the editor gained or lost focus
//     error   – a script error, for the app's log

import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import { TaskList, TaskItem } from '@tiptap/extension-list'
import { Placeholder } from '@tiptap/extensions'
import { Markdown } from '@tiptap/markdown'

const post = (message) => {
  try {
    window.webkit?.messageHandlers?.schema?.postMessage(message)
  } catch (_) {
    // Running outside the app (a browser while developing): nothing to tell.
  }
}

// Script errors go to the app's log, since the web view has no console of its own.
window.addEventListener('error', (event) => post({ type: 'error', message: String(event.message), source: `${event.filename}:${event.lineno}` }))
window.addEventListener('unhandledrejection', (event) => post({ type: 'error', message: String(event.reason) }))

let changeTimer = null
const sendChange = (editor) => {
  clearTimeout(changeTimer)
  changeTimer = setTimeout(() => {
    post({ type: 'change', json: editor.getJSON(), text: editor.getText({ blockSeparator: '\n' }) })
  }, 250)
}

const editor = new Editor({
  element: document.querySelector('#editor'),
  extensions: [
    StarterKit.configure({
      heading: { levels: [1, 2, 3] },
      link: { openOnClick: false },
    }),
    TaskList,
    TaskItem.configure({ nested: true }),
    Placeholder.configure({
      placeholder: ({ editor: e }) => (e.isEmpty ? 'Start writing, or type / for blocks' : 'Type / for blocks'),
      showOnlyCurrent: true,
    }),
    Markdown,
  ],
  autofocus: false,
  editorProps: {
    attributes: { 'aria-label': 'Page', spellcheck: 'true' },
    handleKeyDown: (_view, event) => {
      if (event.key === 'Escape') {
        post({ type: 'escape' })
        return true
      }
      return false
    },
  },
  onUpdate: ({ editor: e }) => sendChange(e),
  onFocus: () => post({ type: 'focus', focused: true }),
  onBlur: () => post({ type: 'focus', focused: false }),
})

window.schemaEditor = {
  setContent(json) {
    const started = performance.now()
    editor.commands.setContent(json, { emitUpdate: false })
    // Measure until the next frame is drawn, so layout is included.
    requestAnimationFrame(() => post({ type: 'loaded', ms: performance.now() - started }))
  },
  setMarkdown(markdown) {
    editor.commands.setContent(markdown, { emitUpdate: false, contentType: 'markdown' })
  },
  getJSON() {
    return editor.getJSON()
  },
  getMarkdown() {
    return editor.getMarkdown()
  },
  focus(where) {
    editor.commands.focus(where || 'end')
  },
}

post({ type: 'ready' })
