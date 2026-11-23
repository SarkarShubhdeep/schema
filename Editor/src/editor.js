// Schema's page editor: TipTap (ProseMirror) inside a WKWebView (#76).
//
// Bridge
//   Swift → JS: window.schemaEditor.setContent(json, key), .focus(where), .getJSON(),
//     .setTaskContext({ pages, tasks }), .linkTask(ref, taskId) (see tasks.js),
//     .setMentionContext({ pages, tasks }) (see mention.js),
//     .setTypography(on): replacements as you type, from Settings (see typography.js),
//     .setSnippets([{ trigger, text }]): your own snippets, from Settings (see snippets.js),
//     .setMode("page" | "note"): Quick note (#82) is a small note, not a page:
//     Return saves, ⇧Return starts a new line, ⌘Return saves as a task, and
//     there is no block handle.
//     key names the page or task the document belongs to. A new key gets a
//     fresh undo history, and every change carries the key it was made in,
//     so a change still pending when the page switches is saved to its page.
//   JS → Swift: webkit.messageHandlers.schema.postMessage({ type, ... })
//     ready   – the editor is mounted and can take content
//     change  – the document changed (debounced); carries key, json and plain text
//     loaded  – a document from setContent is on screen; carries ms
//     escape  – Esc pressed with nothing to close, so the app can take focus
//     focus   – the editor gained or lost focus
//     copyMarkdown – Copy as Markdown on a block; carries the block as a document
//     makeTask – make a task from a to-do (#80); carries ref, text and pageId.
//                The app answers with linkTask(ref, taskId), or null if it could not.
//     openTask – open the task a to-do was made into; carries taskId
//     changeDefaultPage – "Change the default page…" from Make task in
//     openMention – a mention chip was clicked (#81); carries kind and id
//     editCommand – Cut, Copy or Paste from the right-click menu (#83); carries
//                command, which the app runs on the web view as ⌘X, ⌘C or ⌘V would
//     submit   – Quick note (mode "note", #82): Return saves; carries asTask (⌘Return) and json
//     error   – a script error, for the app's log

import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import { TaskList, TaskItem } from '@tiptap/extension-list'
import { Placeholder } from '@tiptap/extensions'
import { Markdown } from '@tiptap/markdown'
import { EditorState } from '@tiptap/pm/state'
import { installHandle } from './handle.js'
import { updateSlash, openTurnInto } from './slash.js'
import { menuKeyDown, isMenuOpen, closeMenu } from './menu.js'
import { blockAt, duplicate } from './blocks.js'
import { markdownPaste } from './paste.js'
import { installTasks, setTaskContext, linkTask, toggleToDos } from './tasks.js'
import { Mention, setMentionContext, updateMention } from './mention.js'
import { RevealMarkdown, restoreRevealed } from './reveal.js'
import { SchemaTypography, setTypography } from './typography.js'
import { Snippets, setSnippets } from './snippets.js'

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

// A to-do made into a task keeps the task's id (#40, #77), so ticking one
// can tick the other. Without this attribute TipTap would drop the id.
const SchemaTaskItem = TaskItem.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      taskId: {
        default: null,
        keepOnSplit: false,
        parseHTML: (element) => element.getAttribute('data-task-id'),
        renderHTML: (attributes) => (attributes.taskId ? { 'data-task-id': attributes.taskId } : {}),
      },
    }
  },
})

let currentKey = null
let changeTimer = null
const postChange = (e) => {
  clearTimeout(changeTimer)
  changeTimer = null
  post({ type: 'change', key: currentKey, json: e.getJSON(), text: e.getText({ blockSeparator: '\n' }) })
}
const sendChange = (e) => {
  clearTimeout(changeTimer)
  changeTimer = setTimeout(() => postChange(e), 250)
}
// Sends a change that is still waiting, before the document is replaced or
// the app takes focus.
const flushChange = (e) => {
  if (changeTimer !== null) postChange(e)
}

const isMac = /Mac/.test(navigator.platform)
let mode = 'page'

// ⇧Return in a note: what Return does on a page (a new list item or block).
const newLine = (e) => e.commands.first(({ commands }) => [
  () => commands.splitListItem('taskItem'),
  () => commands.splitListItem('listItem'),
  () => commands.splitBlock(),
])

const editor = new Editor({
  element: document.querySelector('#editor'),
  extensions: [
    StarterKit.configure({
      heading: { levels: [1, 2, 3] },
      link: { openOnClick: false },
    }),
    TaskList,
    SchemaTaskItem.configure({ nested: true }),
    Placeholder.configure({
      placeholder: ({ editor: e }) => {
        if (mode === 'note') return e.isEmpty ? 'Write a note…' : ''
        return e.isEmpty ? 'Start writing, or type / for blocks' : 'Type / for blocks'
      },
      showOnlyCurrent: true,
    }),
    Mention,
    Markdown,
    RevealMarkdown,
    Snippets,
    SchemaTypography,
  ],
  autofocus: false,
  editorProps: {
    attributes: { 'aria-label': 'Page', spellcheck: 'true' },
    handlePaste: (view, event) => markdownPaste(editor)(view, event),
    handleKeyDown: (_view, event) => {
      // An open menu takes ↑ ↓ Return Esc first.
      if (isMenuOpen() && menuKeyDown(event)) return true
      if (mode === 'note' && event.key === 'Enter' && !event.isComposing && !event.altKey) {
        // The note goes with it: the last change may still be waiting.
        const submit = (asTask) => post({ type: 'submit', asTask, json: editor.getJSON() })
        if (isMac ? event.metaKey : event.ctrlKey) submit(true)
        else if (event.shiftKey) newLine(editor)
        else submit(false)
        return true
      }
      if (event.key === 'Escape') {
        post({ type: 'escape' })
        return true
      }
      const mod = isMac ? event.metaKey : event.ctrlKey
      // ⌘Return in a to-do ticks it (#97); elsewhere it stays a line break.
      if (mod && !event.shiftKey && !event.altKey && event.key === 'Enter' && !event.isComposing) {
        return toggleToDos(editor)
      }
      if (mod && !event.shiftKey && !event.altKey && event.key === '/') {
        openTurnInto(editor)
        return true
      }
      if (mod && !event.shiftKey && !event.altKey && event.key.toLowerCase() === 'd') {
        const block = blockAt(editor.state.doc, editor.state.selection.from)
        if (block) duplicate(editor, block)
        return true
      }
      return false
    },
  },
  onUpdate: ({ editor: e }) => {
    sendChange(e)
    updateMention(e)
    updateSlash(e)
  },
  onSelectionUpdate: ({ editor: e }) => {
    restoreRevealed(e)
    updateMention(e)
    updateSlash(e)
  },
  onFocus: () => post({ type: 'focus', focused: true }),
  onBlur: ({ editor: e }) => {
    restoreRevealed(e, true)
    flushChange(e)
    post({ type: 'focus', focused: false })
  },
})

window.schemaEditor = {
  setContent(json, key) {
    const started = performance.now()
    flushChange(editor)
    closeMenu()
    handle.reset()
    if (key !== currentKey) {
      // Another page: its own document and its own undo history.
      currentKey = key
      const doc = editor.schema.nodeFromJSON(json)
      editor.view.updateState(EditorState.create({ doc, plugins: editor.state.plugins }))
    } else {
      editor.commands.setContent(json, { emitUpdate: false })
    }
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
  setTaskContext(context) {
    setTaskContext(editor, context)
  },
  linkTask(ref, taskId) {
    linkTask(editor, ref, taskId)
  },
  setMentionContext(context) {
    setMentionContext(editor, context)
  },
  setTypography(on) {
    setTypography(on)
  },
  setSnippets(list) {
    setSnippets(list)
  },
  setMode(next) {
    mode = next === 'note' ? 'note' : 'page'
    document.body.classList.toggle('is-note', mode === 'note')
    handle.reset()
    editor.view.dispatch(editor.state.tr.setMeta('addToHistory', false))
  },
}

const handle = installHandle(editor)
installTasks(editor)

// Menus opened from the handle take keys even when the text has no focus.
document.addEventListener('keydown', (event) => {
  if (editor.view.dom.contains(event.target)) return
  if (menuKeyDown(event)) event.preventDefault()
}, true)

// Clicking below the last line keeps writing there.
document.addEventListener('mousedown', (event) => {
  if (editor.view.dom.contains(event.target)) return
  if (event.target.closest?.('.schema-handle, .schema-menu')) return
  event.preventDefault()
  editor.commands.focus('end')
})

post({ type: 'ready' })
