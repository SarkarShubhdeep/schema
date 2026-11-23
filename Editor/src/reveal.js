// Backspace brings the markdown back (#98). At the start of a heading, a
// to-do, a list item or a quote, Backspace turns the block into a plain line
// that starts with the markdown that made it ("# ", "[ ] ", "[x] ", "- ",
// "1. ", "> "), so it can be edited. When the caret leaves that line (or the
// editor loses focus), the line becomes a block again from whatever markdown
// it now starts with: typing x between the brackets makes a ticked to-do.
// Deleting the markdown leaves a plain line, as Backspace did before.
//
// Which lines are revealed lives in the editor only, never in the saved
// page. A to-do linked to a task keeps its task id here while revealed and
// gets it back when it becomes a to-do again.

import { Extension } from '@tiptap/core'
import { Plugin, PluginKey, TextSelection } from '@tiptap/pm/state'
import { canJoin } from '@tiptap/pm/transform'

const key = new PluginKey('schemaReveal')

// { id, pos, taskId }: pos is where the revealed paragraph starts.
let nextID = 0
const revealed = (state) => key.getState(state) || []

const listItemTypes = new Set(['taskItem', 'listItem'])

// The markdown a block was made from, and how to make it again.
const prefixFor = ($from) => {
  const d = $from.depth
  const block = $from.parent
  if (block.type.name === 'heading') return { prefix: '#'.repeat(block.attrs.level) + ' ', lift: null }
  if (block.type.name !== 'paragraph' || d < 2) return null
  const holder = $from.node(d - 1)
  // Only a holder's first line, and only when it holds nothing else.
  if ($from.index(d - 1) !== 0 || holder.childCount !== 1) return null
  if (holder.type.name === 'blockquote') return { prefix: '> ', lift: 'blockquote' }
  if (!listItemTypes.has(holder.type.name) || d < 3) return null
  // Top-level items only: nested ones keep Backspace's usual join and lift.
  if (d >= 4 && listItemTypes.has($from.node(d - 3).type.name)) return null
  const list = $from.node(d - 2)
  if (holder.type.name === 'taskItem') {
    return { prefix: holder.attrs.checked ? '[x] ' : '[ ] ', lift: 'taskItem', taskId: holder.attrs.taskId || null }
  }
  if (list.type.name === 'orderedList') {
    return { prefix: `${(list.attrs.start || 1) + $from.index(d - 2)}. `, lift: 'listItem' }
  }
  return { prefix: '- ', lift: 'listItem' }
}

function reveal(editor) {
  const { selection } = editor.state
  if (!selection.empty || selection.$from.parentOffset !== 0) return false
  const found = prefixFor(selection.$from)
  if (!found) return false
  const { prefix, lift, taskId } = found
  const chain = editor.chain()
  if (lift === 'blockquote') chain.lift('blockquote')
  else if (lift) chain.liftListItem(lift)
  else chain.setNode('paragraph')
  return chain
    .command(({ tr }) => {
      const at = tr.selection.from
      const $at = tr.doc.resolve(at)
      if ($at.parent.type.name !== 'paragraph' || $at.parentOffset !== 0) return false
      tr.insertText(prefix, at)
      tr.setSelection(TextSelection.create(tr.doc, at + prefix.length))
      tr.setMeta(key, { add: { id: ++nextID, pos: $at.before(), taskId: taskId || null } })
      return true
    })
    .run()
}

// What a revealed line's markdown makes, or null for a plain line.
const parse = (text) => {
  let m
  if ((m = /^(#{1,3}) /.exec(text))) return { length: m[0].length, kind: 'heading', level: m[1].length }
  if ((m = /^\[([ xX]?)\] /.exec(text))) return { length: m[0].length, kind: 'todo', checked: m[1].toLowerCase() === 'x' }
  if ((m = /^[-*+] /.exec(text))) return { length: m[0].length, kind: 'bullet' }
  if ((m = /^(\d+)\. /.exec(text))) return { length: m[0].length, kind: 'ordered', start: Number(m[1]) }
  if ((m = /^> /.exec(text))) return { length: m[0].length, kind: 'quote' }
  return null
}

// Turns one revealed line back into a block, keeping the caret where it was.
function restore(editor, entry) {
  const { state } = editor
  const node = state.doc.nodeAt(entry.pos)
  const drop = (tr) => tr.setMeta(key, { remove: entry.id })
  if (!node || node.type.name !== 'paragraph') {
    editor.view.dispatch(drop(state.tr))
    return
  }
  const $pos = state.doc.resolve(entry.pos)
  // Already made into a to-do by typing "[ ] " again: give back its task,
  // and join the to-dos around it, as Backspace had split them.
  if ($pos.parent.type.name === 'taskItem') {
    const tr = drop(state.tr)
    if (entry.taskId && !$pos.parent.attrs.taskId) {
      tr.setNodeMarkup($pos.before(), undefined, { ...$pos.parent.attrs, taskId: entry.taskId })
    }
    const list = $pos.before($pos.depth - 1)
    const after = list + tr.doc.nodeAt(list).nodeSize
    if (canJoin(tr.doc, after)) tr.join(after)
    if (canJoin(tr.doc, list)) tr.join(list)
    editor.view.dispatch(tr)
    return
  }
  const found = parse(node.textContent)
  if (!found) {
    editor.view.dispatch(drop(state.tr))
    return
  }
  const bookmark = state.selection.getBookmark()
  const inside = entry.pos + 1
  const chain = editor.chain().command(({ tr }) => {
    drop(tr)
    tr.delete(inside, inside + found.length)
    tr.setSelection(TextSelection.create(tr.doc, inside))
    return true
  })
  switch (found.kind) {
    case 'heading': chain.setNode('heading', { level: found.level }); break
    case 'todo': chain.toggleTaskList(); break
    case 'bullet': chain.toggleBulletList(); break
    case 'ordered': chain.toggleOrderedList(); break
    case 'quote': chain.wrapIn('blockquote'); break
  }
  chain
    .command(({ tr }) => {
      if (found.kind === 'todo') {
        const $line = tr.doc.resolve(tr.mapping.map(inside))
        for (let d = $line.depth; d > 0; d--) {
          const item = $line.node(d)
          if (item.type.name !== 'taskItem') continue
          tr.setNodeMarkup($line.before(d), undefined, { ...item.attrs, checked: found.checked, taskId: entry.taskId || item.attrs.taskId })
          break
        }
      }
      tr.setSelection(bookmark.map(tr.mapping).resolve(tr.doc))
      return true
    })
    .run()
}

// Restores revealed lines the caret is not in; every one when `all`.
let restoring = false
export function restoreRevealed(editor, all = false) {
  if (restoring || revealed(editor.state).length === 0) return
  restoring = true
  try { restoreEach(editor, all) } finally { restoring = false }
}

function restoreEach(editor, all) {
  for (let guard = 0; guard < 100; guard++) {
    const { selection } = editor.state
    const entry = revealed(editor.state).find((e) => {
      if (all) return true
      const node = editor.state.doc.nodeAt(e.pos)
      if (!node) return true
      // Made into a to-do again by typing: its task comes back at once.
      if (editor.state.doc.resolve(e.pos).parent.type.name === 'taskItem') return true
      return selection.head < e.pos + 1 || selection.head > e.pos + node.nodeSize - 1
    })
    if (!entry) return
    restore(editor, entry)
  }
}

export const RevealMarkdown = Extension.create({
  name: 'schemaRevealMarkdown',
  // Before the list keymap, which would otherwise lift the item first.
  priority: 1000,

  addKeyboardShortcuts() {
    return {
      Backspace: ({ editor }) => editor.commands.undoInputRule() || reveal(editor),
    }
  },

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key,
        state: {
          init: () => [],
          apply(tr, entries) {
            const meta = tr.getMeta(key)
            let next = entries
            if (tr.docChanged) {
              next = next.flatMap((e) => {
                const result = tr.mapping.mapResult(e.pos, 1)
                return result.deleted ? [] : [{ ...e, pos: result.pos }]
              })
            }
            if (meta?.remove !== undefined) next = next.filter((e) => e.id !== meta.remove)
            if (meta?.add) next = [...next.filter((e) => e.pos !== meta.add.pos), meta.add]
            return next
          },
        },
      }),
    ]
  },
})
