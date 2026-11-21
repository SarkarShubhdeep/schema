// The block handle (#78): hovering a block shows one six-dot handle in the
// gutter on its left. Drag it to move the block; click it for Turn into,
// Duplicate, Copy as Markdown and Delete. No plus on every line. It hides while typing.

import { blockAt, kindOf, turnInto, duplicate, remove, startDrag, kindsMatching, blockDocument } from './blocks.js'
import { showMenu, closeMenu, isMenuOpen } from './menu.js'
import { taskMenuItems, taskState } from './tasks.js'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

// Shades the block whose menu is open. A decoration, because ProseMirror
// owns the page's elements and would undo a class added by hand.
const activeKey = new PluginKey('schemaActiveBlock')
const activePlugin = new Plugin({
  key: activeKey,
  state: {
    init: () => DecorationSet.empty,
    apply(tr, set) {
      const meta = tr.getMeta(activeKey)
      if (meta === null) return DecorationSet.empty
      if (meta) {
        return DecorationSet.create(tr.doc, [Decoration.node(meta.pos, meta.pos + meta.size, { class: 'schema-block-active' })])
      }
      return set.map(tr.mapping, tr.doc)
    },
  },
  props: { decorations: (state) => activeKey.getState(state) },
})

const GUTTER = 28
const isMac = /Mac/.test(navigator.platform)

// Copy as Markdown hands the block to the app, which writes the Markdown
// (the same writer as the page's Copy as Markdown) to the clipboard.
const copyMarkdown = (block) => {
  try {
    window.webkit?.messageHandlers?.schema?.postMessage({ type: 'copyMarkdown', json: blockDocument(block) })
  } catch (_) {
    // Outside the app there is no clipboard writer.
  }
}

export function blockMenuItems(editor, block) {
  const current = kindOf(block)
  // A to-do can become a task (#80), or open the task it already is.
  const task = taskState(block.node)
  const taskItems = task?.linked
    ? taskMenuItems(editor, block.pos)
    : (task?.canMake ? [{ title: 'Make task in', submenu: () => taskMenuItems(editor, block.pos) }] : [])
  return [
    {
      title: 'Turn into',
      selected: true,
      submenu: () => kindsMatching('', { insert: false }).map((k) => ({
        title: k.title,
        glyph: k.glyph,
        trail: k.hint,
        checked: k.id === current,
        selected: k.id === current,
        run: () => turnInto(editor, block, k.id),
      })),
    },
    ...taskItems,
    {
      title: 'Duplicate',
      trail: '⌘D',
      key: (e) => (isMac ? e.metaKey : e.ctrlKey) && e.key.toLowerCase() === 'd',
      run: () => duplicate(editor, block),
    },
    {
      title: 'Copy as Markdown',
      run: () => copyMarkdown(block),
    },
    { separator: true },
    {
      title: 'Delete',
      trail: '⌫',
      danger: true,
      key: (e) => e.key === 'Backspace' || e.key === 'Delete',
      run: () => remove(editor, block),
    },
  ]
}

export function installHandle(editor) {
  editor.registerPlugin(activePlugin)
  const shade = (block) => editor.view.dispatch(editor.state.tr.setMeta(activeKey, block ? { pos: block.pos, size: block.node.nodeSize } : null))
  const container = editor.view.dom.parentElement // #editor
  const handle = document.createElement('button')
  handle.type = 'button'
  handle.className = 'schema-handle'
  handle.draggable = true
  handle.setAttribute('aria-label', 'Block options')
  handle.title = 'Drag to move · click for options'
  handle.innerHTML = '<svg width="10" height="14" viewBox="0 0 10 14" fill="currentColor" aria-hidden="true">'
    + [3, 7, 11].map((y) => `<circle cx="3" cy="${y}" r="1.1"/><circle cx="7" cy="${y}" r="1.1"/>`).join('')
    + '</svg>'
  container.appendChild(handle)

  let hovered = null // { block, dom }
  let active = null // the block whose menu is open

  const hide = () => {
    if (active) return
    handle.classList.remove('is-visible')
    hovered = null
  }

  const domFor = (block) => {
    const dom = editor.view.nodeDOM(block.pos)
    return dom instanceof HTMLElement ? dom : null
  }

  const place = (block, dom) => {
    const box = container.getBoundingClientRect()
    const rect = dom.getBoundingClientRect()
    // List items: left of the bullet or checkbox, which sit in the list's padding.
    const isItem = dom.tagName === 'LI'
    const left = (isItem ? dom.parentElement.getBoundingClientRect().left : rect.left) - GUTTER
    const style = getComputedStyle(isItem ? (dom.querySelector('p') || dom) : dom)
    const lineHeight = parseFloat(style.lineHeight) || 24
    const padTop = isItem ? 0 : parseFloat(style.paddingTop) || 0
    handle.style.left = `${left - box.left}px`
    handle.style.top = `${rect.top - box.top + padTop + (lineHeight - 24) / 2}px`
    handle.classList.add('is-visible')
    hovered = { block, dom }
  }

  container.addEventListener('mousemove', (event) => {
    if (active || event.target === handle || handle.contains(event.target)) return
    const content = editor.view.dom.getBoundingClientRect()
    if (event.clientY < content.top || event.clientY > content.bottom) { hide(); return }
    // Aim inside the text column, even from the gutter, so the handle can be reached.
    const x = Math.min(Math.max(event.clientX, content.left + 40), content.right - 4)
    const at = editor.view.posAtCoords({ left: x, top: event.clientY })
    if (!at) { hide(); return }
    const block = blockAt(editor.state.doc, at.inside >= 0 ? at.inside : at.pos)
    const dom = block && domFor(block)
    if (!dom) { hide(); return }
    place(block, dom)
  })
  container.addEventListener('mouseleave', hide)
  editor.view.dom.addEventListener('keydown', () => { if (!isMenuOpen()) hide() })

  // The block under the handle, looked up again in case the page changed.
  const currentBlock = () => {
    if (!hovered) return null
    const pos = editor.view.posAtDOM(hovered.dom, 0)
    return blockAt(editor.state.doc, pos)
  }

  handle.addEventListener('click', () => {
    if (active) { closeMenu(); return }
    const block = currentBlock()
    if (!block) return
    const anchor = handle.getBoundingClientRect()
    active = block
    handle.classList.add('is-active')
    shade(block)
    showMenu({
      label: 'Block options',
      items: blockMenuItems(editor, block),
      anchor,
      onClose: () => {
        active = null
        handle.classList.remove('is-active')
        shade(null)
        hide()
      },
    })
  })

  handle.addEventListener('dragstart', (event) => {
    closeMenu()
    const block = currentBlock()
    if (!block) { event.preventDefault(); return }
    startDrag(editor, block, event, hovered.dom)
  })
  handle.addEventListener('dragend', hide)

  // A new document (another page) moves everything: start over.
  return { reset: () => { closeMenu(); hide() } }
}
