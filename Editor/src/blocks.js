// Blocks as the user sees them (#78): a list item is its own block, so the
// handle, Turn into, Duplicate and Delete work on one line of a list, not
// the whole list. Everything else is a top-level node.

import { NodeSelection, TextSelection } from '@tiptap/pm/state'

const LIST_ITEMS = new Set(['listItem', 'taskItem'])

// The kinds a block can be, in menu order. `aliases` match what is typed
// after "/" (the same words as the v0.5 menu), `hint` is the markdown
// shortcut shown on the right.
export const KINDS = [
  { id: 'text', title: 'Text', glyph: 'T', hint: '', aliases: ['text', 'paragraph', 'plain'] },
  { id: 'heading', title: 'Heading', glyph: 'H', hint: '#', aliases: ['heading', 'title', 'h1', 'h2', 'h3', '#'] },
  { id: 'bullet', title: 'Bullet list', glyph: '•', hint: '-', aliases: ['bullet list', 'list', 'ul', '-'] },
  { id: 'todo', title: 'To-do', glyph: '○', hint: '[ ]', aliases: ['to-do', 'todo', 'task', 'check', 'checkbox', '[]'] },
  { id: 'quote', title: 'Quote', glyph: '“', hint: '>', aliases: ['quote', 'blockquote', '>'] },
  { id: 'code', title: 'Code', glyph: '{}', hint: '```', aliases: ['code', 'codeblock', 'snippet', '```'] },
  { id: 'divider', title: 'Divider', glyph: '—', hint: '---', aliases: ['divider', 'line', 'separator', 'hr', '---'], insertOnly: true },
]

export const kindsMatching = (query, { insert }) => {
  const q = query.toLowerCase()
  return KINDS.filter((k) => (insert || !k.insertOnly)
    && (!q || k.title.toLowerCase().includes(q) || k.aliases.some((a) => a.startsWith(q))))
}

// The block around a document position: { node, pos } where pos is just
// before the node. Inside a list, the innermost list item.
export function blockAt(doc, pos) {
  const $pos = doc.resolve(Math.max(0, Math.min(pos, doc.content.size)))
  for (let d = $pos.depth; d > 0; d--) {
    if (LIST_ITEMS.has($pos.node(d).type.name)) return { node: $pos.node(d), pos: $pos.before(d) }
  }
  if ($pos.depth >= 1) return { node: $pos.node(1), pos: $pos.before(1) }
  if ($pos.nodeAfter) return { node: $pos.nodeAfter, pos: $pos.pos }
  if ($pos.nodeBefore) return { node: $pos.nodeBefore, pos: $pos.pos - $pos.nodeBefore.nodeSize }
  return null
}

// What a block is, as one of KINDS' ids.
export function kindOf(block) {
  switch (block.node.type.name) {
    case 'heading': return 'heading'
    case 'listItem': return 'bullet'
    case 'taskItem': return 'todo'
    case 'blockquote': return 'quote'
    case 'codeBlock': return 'code'
    case 'horizontalRule': return 'divider'
    default: return 'text'
  }
}

// Puts the caret in the block's first line of text.
export function selectInside(editor, block) {
  const { state } = editor
  const inside = Math.min(block.pos + 1, state.doc.content.size)
  editor.view.dispatch(state.tr.setSelection(TextSelection.near(state.doc.resolve(inside))))
}

// Turn the block into another kind. It leaves any list or quote first, so
// one line of a list can become a heading and the rest of the list stays.
export function turnInto(editor, block, kind) {
  if (kindOf(block) === kind) return
  if (block.node.type.name === 'horizontalRule') return
  selectInside(editor, block)
  const lift = () => {
    for (let guard = 0; guard < 8; guard++) {
      if (editor.isActive('taskItem')) editor.commands.liftListItem('taskItem')
      else if (editor.isActive('listItem')) editor.commands.liftListItem('listItem')
      else if (editor.isActive('blockquote')) editor.commands.lift('blockquote')
      else break
    }
    editor.commands.setParagraph()
  }
  lift()
  const chain = editor.chain().focus()
  switch (kind) {
    case 'heading': chain.setHeading({ level: 2 }).run(); break
    case 'bullet': chain.toggleBulletList().run(); break
    case 'todo': chain.toggleTaskList().run(); break
    case 'quote': chain.setBlockquote().run(); break
    case 'code': chain.setCodeBlock().run(); break
    case 'divider': chain.setHorizontalRule().run(); break
    default: chain.run()
  }
}

// A copy goes right below. A copied to-do is not linked to the task.
export function duplicate(editor, block) {
  const json = block.node.toJSON()
  const unlink = (n) => {
    if (n.type === 'taskItem' && n.attrs) n.attrs = { ...n.attrs, taskId: null }
    ;(n.content || []).forEach(unlink)
  }
  unlink(json)
  const copy = editor.schema.nodeFromJSON(json)
  const at = block.pos + block.node.nodeSize
  const tr = editor.state.tr.insert(at, copy)
  tr.setSelection(TextSelection.near(tr.doc.resolve(at + 1)))
  editor.view.dispatch(tr.scrollIntoView())
  editor.commands.focus()
}

export function remove(editor, block) {
  const { state } = editor
  const $pos = state.doc.resolve(block.pos)
  let from = block.pos
  let to = block.pos + block.node.nodeSize
  // The only item of a list takes its list with it.
  if (LIST_ITEMS.has(block.node.type.name) && $pos.parent.childCount === 1) {
    from = $pos.before($pos.depth)
    to = $pos.after($pos.depth)
  }
  let tr = state.tr
  if (from === 0 && to === state.doc.content.size) {
    // The page's last block: leave one empty line.
    tr = tr.replaceWith(0, to, state.schema.nodes.paragraph.create())
  } else {
    tr = tr.delete(from, to)
  }
  tr.setSelection(TextSelection.near(tr.doc.resolve(Math.min(from, tr.doc.content.size))))
  editor.view.dispatch(tr)
  editor.commands.focus()
}

// Starts dragging the block from its handle: ProseMirror moves it on drop
// and the drop cursor shows where it will land.
export function startDrag(editor, block, event, dom) {
  const { view } = editor
  const selection = NodeSelection.create(view.state.doc, block.pos)
  view.dispatch(view.state.tr.setSelection(selection))
  event.dataTransfer.clearData()
  event.dataTransfer.setData('text/plain', block.node.textContent)
  event.dataTransfer.effectAllowed = 'move'
  if (dom) event.dataTransfer.setDragImage(dom, 0, 12)
  view.dragging = { slice: selection.content(), move: true }
}
