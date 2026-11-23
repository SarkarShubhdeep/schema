// Go to line from a tag page (#102, #113): the caret to a block by its path
// in the document, and the page scrolled to it.

import { TextSelection } from '@tiptap/pm/state'

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
