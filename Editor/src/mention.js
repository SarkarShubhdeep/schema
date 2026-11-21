// @ mentions (#81). Typing @ opens one menu: Dates (Today, Now, Tomorrow),
// then matching pages and open tasks. The choice becomes a grey chip with a
// small icon; clicking it asks the app to open the page, the task, or the
// day (Today or Upcoming). Chips of pages and tasks show their current
// names, so renaming a page updates its chips.
//
// A mention is one inline node { kind, id, label } so other kinds (GitHub
// issues in v0.6) only need a new kind. label is the name when it was last
// seen, kept for search, Markdown and items that no longer exist.
//
// The app sends what can be mentioned with setMentionContext:
//   { pages: [{ id, title, kind }], tasks: [{ id, title, page }] }
// kind is "todo" or "scratchpad"; tasks are the open ones.

import { Node, mergeAttributes } from '@tiptap/core'
import { showMenu, updateMenu, closeMenu } from './menu.js'

const post = (message) => {
  try {
    window.webkit?.messageHandlers?.schema?.postMessage(message)
  } catch (_) {
    // Running outside the app: nothing to open.
  }
}

let context = { pages: [], tasks: [] }
let names = new Map() // id → current name, pages and tasks
const views = new Set() // chips on screen, to rename in place

// MARK: Dates

const pad = (n) => String(n).padStart(2, '0')
const dayID = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
const parseDay = (id) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(id || '')
  return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])) : null
}
const dayText = (d) => d.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short' })
const timeText = (d) => d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })

// What a chip says now.
export function mentionLabel(attrs) {
  switch (attrs.kind) {
    case 'page':
    case 'task':
      return names.get(attrs.id) || attrs.label || 'Untitled'
    case 'date': {
      const d = parseDay(attrs.id)
      return d ? dayText(d) : attrs.label
    }
    case 'time': {
      const d = new Date(attrs.id)
      return Number.isNaN(d.getTime()) ? attrs.label : `${dayText(d)}, ${timeText(d)}`
    }
    default:
      return attrs.label || ''
  }
}

const ICONS = {
  page: '<svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 1.5h5.5l2.5 2.5v8.5H3z"/><path d="M5 6.5h4M5 9h3"/></svg>',
  task: '<svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><circle cx="7" cy="7" r="5.5"/></svg>',
  date: '<svg width="12" height="12" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><rect x="3" y="4.5" width="14" height="12" rx="2"/><path d="M3 8.5h14M7 2.5v4M13 2.5v4"/></svg>',
  time: '<svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" aria-hidden="true"><circle cx="7" cy="7" r="5.5"/><path d="M7 4v3l2 1.5"/></svg>',
}

const exists = (attrs) => (attrs.kind !== 'page' && attrs.kind !== 'task') || names.has(attrs.id)

export const Mention = Node.create({
  name: 'mention',
  group: 'inline',
  inline: true,
  atom: true,
  selectable: false,

  addAttributes() {
    return {
      kind: { default: 'page', parseHTML: (el) => el.getAttribute('data-kind'), renderHTML: (a) => ({ 'data-kind': a.kind }) },
      id: { default: null, parseHTML: (el) => el.getAttribute('data-id'), renderHTML: (a) => ({ 'data-id': a.id }) },
      label: { default: '', parseHTML: (el) => el.getAttribute('data-label') || el.textContent, renderHTML: (a) => ({ 'data-label': a.label }) },
    }
  },

  parseHTML() {
    return [{ tag: 'span[data-mention]' }]
  },

  renderHTML({ node, HTMLAttributes }) {
    return ['span', mergeAttributes({ 'data-mention': '' }, HTMLAttributes), mentionLabel(node.attrs)]
  },

  renderText({ node }) {
    return mentionLabel(node.attrs)
  },

  renderMarkdown(node) {
    return mentionLabel(node.attrs || {})
  },

  addNodeView() {
    return ({ node }) => {
      const dom = document.createElement('span')
      dom.className = 'schema-mention'
      dom.contentEditable = 'false'
      dom.setAttribute('role', 'link')
      dom.setAttribute('data-mention', '')
      const icon = document.createElement('span')
      icon.className = 'schema-mention-icon'
      const text = document.createElement('span')
      dom.append(icon, text)
      let attrs = node.attrs
      const draw = () => {
        icon.innerHTML = ICONS[attrs.kind] || ''
        text.textContent = mentionLabel(attrs)
        dom.classList.toggle('is-missing', !exists(attrs))
        dom.title = !exists(attrs) ? `${mentionLabel(attrs)} no longer exists` : `Open ${mentionLabel(attrs)}`
      }
      draw()
      dom.addEventListener('mousedown', (e) => e.preventDefault())
      dom.addEventListener('click', () => {
        if (exists(attrs)) post({ type: 'openMention', kind: attrs.kind, id: attrs.id })
      })
      const view = { draw }
      views.add(view)
      return {
        dom,
        update(next) {
          if (next.type.name !== 'mention') return false
          attrs = next.attrs
          draw()
          return true
        },
        ignoreMutation: () => true,
        stopEvent: (e) => e.type === 'mousedown' || e.type === 'click',
        destroy() { views.delete(view) },
      }
    }
  },
})

// The app's pages and tasks. Chips redraw, and stored labels catch up with
// renames so search and Markdown say the new name too.
export function setMentionContext(editor, next) {
  context = { pages: next?.pages || [], tasks: next?.tasks || [] }
  names = new Map()
  for (const p of context.pages) names.set(p.id, p.title)
  for (const t of context.tasks) names.set(t.id, t.title)
  views.forEach((v) => v.draw())
  const { state } = editor
  let tr = state.tr
  state.doc.descendants((node, pos) => {
    if (node.type.name !== 'mention') return
    const { kind, id, label } = node.attrs
    if ((kind === 'page' || kind === 'task') && names.has(id) && names.get(id) !== label) {
      tr = tr.setNodeMarkup(pos, undefined, { ...node.attrs, label: names.get(id) })
    }
  })
  if (tr.docChanged) editor.view.dispatch(tr.setMeta('addToHistory', false))
  if (at) updateMenu(atItems(editor))
}

// MARK: The @ menu

let at = null // { from, to, query } while the menu is open
let dismissed = null

// "@query" right before the caret, at the start of a line or after a space.
function atBeforeCaret(state) {
  const { selection } = state
  if (!selection.empty) return null
  const { $from } = selection
  const parent = $from.parent
  if (!parent.isTextblock || parent.type.name === 'codeBlock') return null
  if ($from.marks().some((m) => m.type.name === 'code')) return null
  const text = parent.textBetween(0, $from.parentOffset, undefined, '￼')
  const match = /(?:^|[\s(])@([^@\n￼]{0,40})$/.exec(text)
  if (!match) return null
  const query = match[1]
  if (/^\s/.test(query) || /\s\s/.test(query)) return null
  return { from: $from.pos - query.length - 1, to: $from.pos, query, key: `${$from.start()}:${text.length - query.length}` }
}

const matches = (title, q) => {
  const t = title.toLowerCase()
  return !q || t.startsWith(q) || t.includes(` ${q}`) || t.includes(q)
}

function choices(query) {
  const q = query.trim().toLowerCase()
  const now = new Date()
  const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
  const dates = [
    { title: 'Today', trail: dayText(now), attrs: { kind: 'date', id: dayID(now), label: dayText(now) } },
    { title: 'Now', trail: timeText(now), attrs: { kind: 'time', id: now.toISOString(), label: `${dayText(now)}, ${timeText(now)}` } },
    { title: 'Tomorrow', trail: dayText(tomorrow), attrs: { kind: 'date', id: dayID(tomorrow), label: dayText(tomorrow) } },
  ].filter((d) => matches(d.title, q))
  const pages = context.pages.filter((p) => matches(p.title, q)).slice(0, q ? 6 : 4).map((p) => ({
    title: p.title,
    trail: p.kind === 'scratchpad' ? 'Scratchpad' : 'To-do list',
    attrs: { kind: 'page', id: p.id, label: p.title },
  }))
  const tasks = q ? context.tasks.filter((t) => matches(t.title, q)).slice(0, 6).map((t) => ({
    title: t.title,
    trail: t.page,
    attrs: { kind: 'task', id: t.id, label: t.title },
  })) : []
  return { dates, pages, tasks }
}

function atItems(editor) {
  const { dates, pages, tasks } = choices(at.query)
  const items = []
  let first = true
  const add = (header, list) => {
    if (!list.length) return
    items.push({ header })
    for (const c of list) {
      items.push({ title: c.title, trail: c.trail, selected: first, run: () => insert(editor, c.attrs) })
      first = false
    }
  }
  add('Dates', dates)
  add('Pages', pages)
  add('Tasks', tasks)
  items.push({ footer: '↑↓ to move · ↩ to insert · esc to close' })
  return items
}

function insert(editor, attrs) {
  const found = atBeforeCaret(editor.state)
  at = null
  if (!found) return
  editor.chain().focus().insertContentAt({ from: found.from, to: found.to }, [
    { type: 'mention', attrs },
    { type: 'text', text: ' ' },
  ]).run()
}

function caretRect(editor) {
  const coords = editor.view.coordsAtPos(editor.state.selection.from)
  return { left: coords.left - 8, right: coords.right, top: coords.top, bottom: coords.bottom }
}

// After every change or caret move: open, filter or close the @ menu.
// Returns true while it is open, so the / menu leaves it alone.
export function updateMention(editor) {
  const found = atBeforeCaret(editor.state)
  if (found && dismissed === found.key) return false
  // A space with nothing matching ends it: "@ " or "email me @ 5".
  const hasChoices = found && (() => { const c = choices(found.query); return c.dates.length + c.pages.length + c.tasks.length > 0 })()
  if (!found || (!hasChoices && /\s$/.test(found.query))) {
    if (!found) dismissed = null
    if (at) { at = null; closeMenu() }
    return false
  }
  const opening = !at
  at = found
  if (opening) {
    showMenu({
      label: 'Mention',
      items: atItems(editor),
      anchor: caretRect(editor),
      onClose: () => {
        const still = atBeforeCaret(editor.state)
        if (at && still) dismissed = still.key
        at = null
      },
    })
  } else {
    updateMenu(atItems(editor))
  }
  return true
}
