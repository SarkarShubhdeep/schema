// To-do lines and tasks (#80), as in v0.5 (#40). Hovering an open to-do,
// or writing in it, shows "Make task in …" on the right for the default
// page; right-clicking it offers every to-do page. A to-do made into a task
// keeps the task's id and shows "Task in …", which opens the task. Ticking
// either ticks both: the app does that when it saves.
//
// The app sends what the editor needs to know with setTaskContext:
//   { pages: [{ id, title, isDefault }], tasks: { [taskId]: { page, pageId } } }
// Pages is empty where lines cannot become tasks (a task's own page).

import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import { showMenu } from './menu.js'

const post = (message) => {
  try {
    window.webkit?.messageHandlers?.schema?.postMessage(message)
  } catch (_) {
    // Running outside the app: nothing makes tasks.
  }
}

let context = { pages: [], tasks: {} }
const key = new PluginKey('schemaTasks')

// A made-up id the line holds until the app answers with the task's id.
const newRef = () => {
  const b = crypto.getRandomValues(new Uint8Array(16))
  b[6] = (b[6] & 0x0f) | 0x40
  b[8] = (b[8] & 0x3f) | 0x80
  const h = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('').toUpperCase()
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
}
const pending = new Set()

const defaultPage = () => context.pages.find((p) => p.isDefault) || context.pages[0] || null
const textOf = (node) => (node.firstChild?.textContent || '').trim()

// What a to-do line offers: its task, or making one.
export function taskState(node) {
  if (node?.type.name !== 'taskItem') return null
  const id = node.attrs.taskId
  const task = id ? context.tasks[id] : null
  if (task) return { linked: true, id, page: task.page, pageId: task.pageId }
  if (id && pending.has(id)) return { pending: true }
  if (node.attrs.checked || !textOf(node) || context.pages.length === 0) return null
  return { canMake: true }
}

export function makeTask(editor, pos, page) {
  const node = editor.state.doc.nodeAt(pos)
  if (!page || !taskState(node)?.canMake) return
  const ref = newRef()
  pending.add(ref)
  editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { ...node.attrs, taskId: ref }))
  post({ type: 'makeTask', ref, text: textOf(node), pageId: page.id })
}

export const openTask = (id) => post({ type: 'openTask', taskId: id })

// The line stays, the task stays; they just stop ticking together.
export function unlinkTask(editor, pos) {
  const node = editor.state.doc.nodeAt(pos)
  if (!taskState(node)?.linked) return
  editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { ...node.attrs, taskId: null }))
}

// The app made the task (or could not: id is null).
export function linkTask(editor, ref, id) {
  pending.delete(ref)
  const { state } = editor
  let tr = state.tr
  state.doc.descendants((node, pos) => {
    if (node.type.name === 'taskItem' && node.attrs.taskId === ref) {
      tr = tr.setNodeMarkup(pos, undefined, { ...node.attrs, taskId: id || null })
    }
  })
  if (tr.docChanged) editor.view.dispatch(tr.setMeta('addToHistory', false))
  else redraw(editor)
}

export function setTaskContext(editor, next) {
  context = { pages: next?.pages || [], tasks: next?.tasks || {} }
  redraw(editor)
}

const redraw = (editor) => editor.view.dispatch(editor.state.tr.setMeta(key, true).setMeta('addToHistory', false))

// Menu rows for a to-do: in its right-click menu and the handle's menu.
export function taskMenuItems(editor, pos) {
  const state = taskState(editor.state.doc.nodeAt(pos))
  if (state?.linked) {
    const others = context.pages.filter((page) => page.id !== state.pageId)
    return [
      { title: `Open task in ${state.page}`, run: () => openTask(state.id) },
      ...(others.length ? [{
        title: 'Move task to',
        submenu: () => others.map((page) => ({
          title: page.title,
          run: () => post({ type: 'moveTask', taskId: state.id, pageId: page.id }),
        })),
      }] : []),
      { separator: true },
      { title: 'Unlink from task', run: () => unlinkTask(editor, pos) },
    ]
  }
  if (!state?.canMake) return []
  return context.pages.map((page) => ({
    title: page.title,
    trail: page.isDefault ? 'Default' : '',
    selected: page.isDefault,
    run: () => makeTask(editor, pos, page),
  })).concat([
    { separator: true },
    { title: 'Change the default page…', run: () => post({ type: 'changeDefaultPage' }) },
  ])
}

const button = (className, text, title) => {
  const el = document.createElement('button')
  el.type = 'button'
  el.className = className
  el.textContent = text
  el.title = title
  el.contentEditable = 'false'
  el.addEventListener('mousedown', (e) => e.preventDefault())
  return el
}

// The taskItem a widget sits in.
const itemPos = (view, widgetPos) => {
  const $pos = view.state.doc.resolve(widgetPos)
  for (let d = $pos.depth; d > 0; d--) {
    if ($pos.node(d).type.name === 'taskItem') return $pos.before(d)
  }
  return null
}

const widgets = (editor, doc, selection) => {
  const decorations = []
  // The innermost to-do with the caret shows its badge without hovering.
  let current = null
  const $head = selection.$head
  for (let d = $head.depth; d > 0; d--) {
    if ($head.node(d).type.name === 'taskItem') { current = $head.before(d); break }
  }
  const page = defaultPage()
  doc.descendants((node, pos) => {
    if (node.type.name !== 'taskItem') return true
    const state = taskState(node)
    const after = pos + 1 + (node.firstChild?.nodeSize || 0)
    if (pos === current) decorations.push(Decoration.node(pos, pos + node.nodeSize, { class: 'is-current' }))
    if (state?.linked) {
      const label = `Task in ${state.page}`
      decorations.push(Decoration.widget(after, (view) => {
        const el = button('schema-task-link', label, `Open the task in ${state.page}`)
        el.appendChild(Object.assign(document.createElement('span'), { className: 'schema-task-link-arrow', textContent: '↗' }))
        el.addEventListener('click', () => openTask(state.id))
        return el
      }, { key: `link:${state.id}:${state.page}`, side: -1, stopEvent: () => true, ignoreSelection: true }))
    } else if (state?.canMake && page) {
      const label = `Make task in ${page.title}`
      decorations.push(Decoration.widget(after, (view, getPos) => {
        const el = button('schema-make-task', label, `Add this line as a task in ${page.title}. Right-click for other pages.`)
        el.addEventListener('click', () => {
          const at = itemPos(view, getPos())
          if (at !== null) makeTask(editor, at, page)
        })
        return el
      }, { key: `make:${page.id}:${page.title}`, side: -1, stopEvent: () => true, ignoreSelection: true }))
    }
    return true
  })
  return DecorationSet.create(doc, decorations)
}

export function installTasks(editor) {
  let cache = null
  editor.registerPlugin(new Plugin({
    key,
    props: {
      decorations(state) {
        if (!cache || cache.doc !== state.doc || cache.selection !== state.selection || cache.context !== context) {
          cache = { doc: state.doc, selection: state.selection, context, set: widgets(editor, state.doc, state.selection) }
        }
        return cache.set
      },
    },
  }))

  // Right-click an open to-do for every to-do page; a linked one opens its task.
  editor.view.dom.addEventListener('contextmenu', (event) => {
    const li = event.target.closest?.('ul[data-type="taskList"] > li')
    if (!li) return
    const { view } = editor
    let pos = null
    try {
      const $pos = view.state.doc.resolve(view.posAtDOM(li, 0))
      for (let d = $pos.depth; d > 0; d--) {
        if ($pos.node(d).type.name === 'taskItem') { pos = $pos.before(d); break }
      }
    } catch (_) {
      return
    }
    if (pos === null) return
    const items = taskMenuItems(editor, pos)
    if (items.length === 0) return
    event.preventDefault()
    const linked = taskState(view.state.doc.nodeAt(pos))?.linked
    showMenu({
      label: linked ? 'Task' : 'Make task in',
      header: linked ? null : 'Make task in',
      items,
      anchor: { left: event.clientX, right: event.clientX, top: event.clientY, bottom: event.clientY },
    })
  })
}
