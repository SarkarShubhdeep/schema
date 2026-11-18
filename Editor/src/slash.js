// The / menu (#78): typing / at the start of a block opens it, the letters
// after / filter it, and choosing an item turns the block into that kind.
// ⌘/ opens Turn into for the block with the caret. Esc closes the menu
// until the text changes.

import { blockAt, kindOf, kindsMatching, turnInto } from './blocks.js'
import { showMenu, updateMenu, closeMenu, isMenuOpen } from './menu.js'

let slash = null // { from, to, query } while the / menu is open
let dismissed = null // "from:text" of a / the user closed with Esc

// "/query" right before the caret, at the start of a text block.
function slashBeforeCaret(state) {
  const { selection } = state
  if (!selection.empty) return null
  const { $from } = selection
  const parent = $from.parent
  if (!parent.isTextblock || parent.type.name === 'codeBlock') return null
  const text = parent.textBetween(0, $from.parentOffset, undefined, '￼')
  const match = /^\/([^\s/￼]{0,24})$/.exec(text)
  if (!match) return null
  return { from: $from.start(), to: $from.pos, query: match[1], key: `${$from.start()}:${text}` }
}

function caretRect(editor) {
  const coords = editor.view.coordsAtPos(editor.state.selection.from)
  return { left: coords.left - 8, right: coords.right, top: coords.top, bottom: coords.bottom }
}

function slashItems(editor) {
  return kindsMatching(slash.query, { insert: true }).map((k, i) => ({
    title: k.title,
    glyph: k.glyph,
    trail: k.hint,
    selected: i === 0,
    run: () => choose(editor, k.id),
  }))
}

function choose(editor, kind) {
  const found = slashBeforeCaret(editor.state)
  slash = null
  if (found) editor.view.dispatch(editor.state.tr.delete(found.from, found.to))
  const block = blockAt(editor.state.doc, editor.state.selection.from)
  if (!block) return
  if (kind === 'divider') {
    editor.chain().focus().setHorizontalRule().run()
  } else {
    turnInto(editor, block, kind)
  }
}

// After every change or caret move: open, filter or close the / menu.
export function updateSlash(editor) {
  const found = slashBeforeCaret(editor.state)
  if (found && dismissed === found.key) return
  if (!found) {
    dismissed = null
    if (slash) { slash = null; closeMenu() }
    return
  }
  const opening = !slash
  slash = found
  if (opening) {
    showMenu({
      label: 'Insert block',
      header: 'Blocks',
      items: slashItems(editor),
      anchor: caretRect(editor),
      onClose: () => {
        // Closed with Esc or a click elsewhere: stay closed for this "/".
        const still = slashBeforeCaret(editor.state)
        if (slash && still) dismissed = still.key
        slash = null
      },
    })
  } else {
    updateMenu(slashItems(editor))
  }
}

// ⌘/: Turn into for the block with the caret.
export function openTurnInto(editor) {
  const block = blockAt(editor.state.doc, editor.state.selection.from)
  if (!block || isMenuOpen()) return
  const current = kindOf(block)
  showMenu({
    label: 'Turn into',
    header: 'Turn into',
    items: kindsMatching('', { insert: false }).map((k) => ({
      title: k.title,
      glyph: k.glyph,
      trail: k.hint,
      checked: k.id === current,
      selected: k.id === current,
      run: () => turnInto(editor, block, k.id),
    })),
    anchor: caretRect(editor),
  })
}
