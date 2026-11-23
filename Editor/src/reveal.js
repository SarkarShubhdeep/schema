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
import { canJoin, findWrapping } from '@tiptap/pm/transform'

const key = new PluginKey('schemaReveal')
// Ids of revealed lines turned back in a transaction.
const removeKey = 'schemaRevealRemoved'

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

// Turns one revealed line back into a block, inside `tr`. Returns false when
// the entry is gone. Runs in appendTransaction, so the change lands in the
// same update as the caret move that caused it: the editor draws the caret
// once, in the right place (a second dispatch from inside an update could
// leave WebKit drawing it where the line used to end).
function restoreIn(tr, entry) {
  tr.setMeta(removeKey, [...(tr.getMeta(removeKey) || []), entry.id])
  const node = tr.doc.nodeAt(entry.pos)
  if (!node || node.type.name !== 'paragraph') return
  const { schema } = tr.doc.type
  const $pos = tr.doc.resolve(entry.pos)
  // Already made into a to-do by typing "[ ] " again: give back its task,
  // and join the to-dos around it, as Backspace had split them.
  if ($pos.parent.type.name === 'taskItem') {
    if (entry.taskId && !$pos.parent.attrs.taskId) {
      tr.setNodeMarkup($pos.before(), undefined, { ...$pos.parent.attrs, taskId: entry.taskId })
    }
    joinAround(tr, $pos.before($pos.depth - 1))
    return
  }
  const found = parse(node.textContent)
  if (!found) return
  const inside = entry.pos + 1
  tr.delete(inside, inside + found.length)
  if (found.kind === 'heading') {
    tr.setNodeMarkup(entry.pos, schema.nodes.heading, { level: found.level })
    return
  }
  const wrapper = {
    todo: [schema.nodes.taskList, null],
    bullet: [schema.nodes.bulletList, null],
    ordered: [schema.nodes.orderedList, { start: found.start }],
    quote: [schema.nodes.blockquote, null],
  }[found.kind]
  const $inside = tr.doc.resolve(inside)
  const range = $inside.blockRange()
  const wrapping = range && findWrapping(range, wrapper[0], wrapper[1])
  if (!wrapping) return
  tr.wrap(range, wrapping)
  if (found.kind === 'todo') {
    const item = tr.doc.nodeAt(entry.pos + 1)
    if (item?.type.name === 'taskItem') {
      tr.setNodeMarkup(entry.pos + 1, undefined, { ...item.attrs, checked: found.checked, taskId: entry.taskId || item.attrs.taskId })
    }
  }
  if (found.kind !== 'quote') joinAround(tr, entry.pos)
}

// Joins the list at `pos` with lists of the same kind right before and after
// it. (canJoin alone would also join a bullet list into a numbered one, or
// try an empty paragraph into a list.)
function joinAround(tr, pos) {
  const list = tr.doc.nodeAt(pos)
  if (!list) return
  const same = (at) => {
    const $at = tr.doc.resolve(at)
    return $at.nodeBefore?.type === list.type && $at.nodeAfter?.type === list.type && canJoin(tr.doc, at)
  }
  const after = pos + list.nodeSize
  if (same(after)) tr.join(after)
  if (same(pos)) tr.join(pos)
}

// Lines to turn back: those the caret isn't in, ones typed back into a
// to-do, and every one when the editor loses focus.
function due(state, all, ids = []) {
  const { head } = state.selection
  return revealed(state).filter((e) => {
    if (all || ids.includes(e.id)) return true
    const node = state.doc.nodeAt(e.pos)
    if (!node) return true
    if (state.doc.resolve(e.pos).parent.type.name === 'taskItem') return true
    return head < e.pos + 1 || head > e.pos + node.nodeSize - 1
  })
}

// Turns every revealed line back, for when the editor loses focus.
export function restoreRevealed(editor) {
  if (revealed(editor.state).length === 0) return
  editor.view.dispatch(editor.state.tr.setMeta(key, { restoreAll: true }))
}

export const RevealMarkdown = Extension.create({
  name: 'schemaRevealMarkdown',
  // Before the list keymap, which would otherwise lift the item first.
  priority: 1000,

  addKeyboardShortcuts() {
    return {
      Backspace: ({ editor }) => editor.commands.undoInputRule() || reveal(editor),
      // Return on a line showing its markdown makes it a block again first,
      // so Return then does what it does there: [x] hello → a ticked to-do,
      // and the new line is a to-do under it.
      Enter: ({ editor }) => {
        const { state } = editor
        const { head } = state.selection
        const entry = revealed(state).find((e) => {
          const node = state.doc.nodeAt(e.pos)
          return node && head > e.pos && head < e.pos + node.nodeSize
        })
        if (entry) editor.view.dispatch(state.tr.setMeta(key, { restoreIds: [entry.id] }))
        return false
      },
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
            const removed = tr.getMeta(removeKey) || []
            if (removed.length) next = next.filter((e) => !removed.includes(e.id))
            if (meta?.remove !== undefined) next = next.filter((e) => e.id !== meta.remove)
            if (meta?.add) next = [...next.filter((e) => e.pos !== meta.add.pos), meta.add]
            return next
          },
        },
        appendTransaction(trs, _old, state) {
          if (trs.some((tr) => tr.getMeta(key)?.restoring)) return null
          const all = trs.some((tr) => tr.getMeta(key)?.restoreAll)
          const ids = trs.flatMap((tr) => tr.getMeta(key)?.restoreIds || [])
          const entries = due(state, all, ids)
          if (entries.length === 0) return null
          const tr = state.tr.setMeta(key, { restoring: true })
          // Last first, so earlier positions stay put.
          for (const entry of [...entries].sort((x, y) => y.pos - x.pos)) {
            restoreIn(tr, { ...entry, pos: tr.mapping.map(entry.pos, 1) })
          }
          return tr
        },
      }),
    ]
  },
})
