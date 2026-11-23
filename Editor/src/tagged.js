// A tag page's lines from other pages (#102, Tag page board). Below the tag
// page's own writing, each page that has lines tagged with it gets a small
// "From <page>" divider and its lines, drawn like the editor draws them:
// to-dos with their checkbox, bullets, numbers, quotes and headings.
//
// They are shown, not copied: ticking one ticks it on its page (and its
// task), and clicking one opens it on its page. Lines live in the page they
// were written on, so editing happens there.
//
// With grouped off (the ⋯ menu's Group by page), they run as one list,
// each with its page named on the right.
//
// The app sends them with setTaggedLines({ hideDone, grouped, groups: [{ title,
// holderId, lines: [{ holderId, path, kind, text, otherTags, checked,
// linkedPage, isTask }] }] }), and an empty list on other pages.

import { TextSelection } from '@tiptap/pm/state'

const post = (message) => {
  try {
    window.webkit?.messageHandlers?.schema?.postMessage(message)
  } catch (_) {
    // Running outside the app: nothing to open.
  }
}

let root = null

const el = (tag, className, text) => {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (text !== undefined) node.textContent = text
  return node
}

function lineRow(line, number) {
  const row = el('div', `tagged-line kind-${line.kind}${line.checked ? ' is-done' : ''}`)
  row.setAttribute('role', 'listitem')
  if (line.kind === 'todo') {
    const box = el('button', 'tagged-check')
    box.type = 'button'
    box.setAttribute('aria-pressed', line.checked ? 'true' : 'false')
    box.setAttribute('aria-label', `${line.checked ? 'Mark not done' : 'Complete'}: ${line.text}`)
    box.addEventListener('click', (e) => {
      e.stopPropagation()
      post({ type: 'toggleTagged', holderId: line.holderId, path: line.path || [], isTask: !!line.isTask, checked: !line.checked })
    })
    row.append(box)
  } else if (line.kind === 'bullet') {
    row.append(el('span', 'tagged-mark', '•'))
  } else if (line.kind === 'numbered') {
    row.append(el('span', 'tagged-mark', `${number}.`))
  } else {
    row.append(el('span', 'tagged-mark'))
  }
  const text = el('span', 'tagged-text', line.text)
  for (const tag of line.otherTags || []) text.append(el('span', 'schema-mention is-tag tagged-chip', `#${tag}`))
  row.append(text)
  const trail = el('span', 'tagged-trail')
  if (line.showsPage) trail.append(el('span', 'tagged-page', line.page))
  if (line.linkedPage) trail.append(el('span', 'schema-task-link', `Task in ${line.linkedPage}`))
  trail.append(el('span', 'tagged-go', 'Go to line ↗'))
  row.append(trail)
  row.title = `Edit on ${line.page}`
  row.addEventListener('click', () => post({ type: 'openTagged', holderId: line.holderId, path: line.path || [], isTask: !!line.isTask }))
  return row
}

export function setTaggedLines(data) {
  const groups = (data?.groups || [])
    .map((g) => ({ ...g, lines: (g.lines || []).filter((l) => !(data.hideDone && l.checked)) }))
    .filter((g) => g.lines.length)
  document.body.classList.toggle('has-tagged', !!data?.groups)
  if (!root) {
    root = el('section', 'tagged')
    root.setAttribute('aria-label', 'Tagged on other pages')
    document.querySelector('#editor')?.after(root)
  }
  root.replaceChildren()
  if (data && data.grouped === false && groups.length) {
    const list = el('div', 'tagged-lines is-flat')
    list.setAttribute('role', 'list')
    list.setAttribute('aria-label', 'Tagged on other pages')
    let number = 0
    for (const group of groups) {
      for (const line of group.lines) {
        number = line.kind === 'numbered' ? number + 1 : 0
        list.append(lineRow({ ...line, page: group.title, showsPage: true }, number))
      }
    }
    root.append(list)
    return
  }
  for (const group of groups) {
    const head = el('div', 'tagged-divider')
    head.append(el('span', 'tagged-from', `From ${group.title}`), el('span', 'tagged-rule'))
    const open = el('button', 'tagged-open', 'Open')
    open.type = 'button'
    open.title = `Open ${group.title}`
    open.addEventListener('click', () => post({ type: 'openTagged', holderId: group.holderId, path: null, isTask: !!group.isTask }))
    head.append(open)
    const list = el('div', 'tagged-lines')
    list.setAttribute('role', 'list')
    list.setAttribute('aria-label', `From ${group.title}`)
    let number = 0
    for (const line of group.lines) {
      number = line.kind === 'numbered' ? number + 1 : 0
      list.append(lineRow({ ...line, page: group.title }, number))
    }
    root.append(head, list)
  }
}

// Puts the caret at the start of the block at `path` and scrolls to it, for
// "Go to line" from a tag page.
export function revealPath(editor, path) {
  const { doc } = editor.state
  let node = doc
  let pos = 0
  for (let depth = 0; depth < path.length; depth++) {
    const index = path[depth]
    if (index < 0 || index >= node.childCount) return
    for (let i = 0; i < index; i++) pos += node.child(i).nodeSize
    node = node.child(index)
    if (depth < path.length - 1) pos += 1
  }
  const selection = TextSelection.near(doc.resolve(Math.min(pos + 1, doc.content.size)))
  editor.chain().focus().setTextSelection(selection.from).run()
  requestAnimationFrame(() => {
    const dom = editor.view.nodeDOM(pos)
    const target = dom?.nodeType === 1 ? dom : dom?.parentElement
    target?.scrollIntoView({ block: 'center', behavior: 'smooth' })
    target?.classList.add('is-revealed')
    setTimeout(() => target?.classList.remove('is-revealed'), 1200)
  })
}
