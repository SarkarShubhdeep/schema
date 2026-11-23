// Synced blocks on tag pages (#113). A tagged block exists once, in the page
// where it was written (Ideas). A tag page (#chores) shows that same block as
// a syncedBlock: real, editable text, ticked or typed in like any block. The
// app writes each change back to the block where it lives, so every page
// that shows it shows the change; and when the block changes elsewhere, the
// app sends it here again (setSyncedBlocks) and it is updated in place.
//
// A syncedBlock holds one paragraph: the block's own line, with its chips.
// It never merges with the blocks around it. Return makes the next block
// where it lives, with the same tags; Backspace in an empty one takes the
// tag off (it leaves this page, and stays where it lives).
//
// Every block also gets a lasting id (bid), so a synced block can be found
// where it lives after that page changes.

import { Node, Extension, mergeAttributes } from '@tiptap/core'
import { Plugin, PluginKey, TextSelection } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

const post = (message) => {
  try {
    window.webkit?.messageHandlers?.schema?.postMessage(message)
  } catch (_) {
    // Running outside the app: nothing to write back.
  }
}

export const newID = () => {
  const b = crypto.getRandomValues(new Uint8Array(16))
  b[6] = (b[6] & 0x0f) | 0x40
  b[8] = (b[8] & 0x3f) | 0x80
  const h = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('').toUpperCase()
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
}

// MARK: Block ids

const ID_TYPES = ['paragraph', 'heading', 'taskItem', 'listItem', 'blockquote', 'codeBlock']

export const BlockIDs = Extension.create({
  name: 'schemaBlockIDs',

  addGlobalAttributes() {
    return [{
      types: ID_TYPES,
      attributes: {
        bid: {
          default: null,
          keepOnSplit: false,
          parseHTML: (el) => el.getAttribute('data-bid'),
          renderHTML: (a) => (a.bid ? { 'data-bid': a.bid } : {}),
        },
      },
    }]
  },

  // A block without an id gets one; a second block with the same id (a
  // split, a paste, Duplicate) gets a new one.
  addProseMirrorPlugins() {
    return [new Plugin({
      appendTransaction(trs, _old, state) {
        if (!trs.some((tr) => tr.docChanged)) return null
        const seen = new Set()
        let tr = null
        state.doc.descendants((node, pos) => {
          if (node.type.name === 'syncedBlock') return false
          if (!ID_TYPES.includes(node.type.name)) return true
          const bid = node.attrs.bid
          if (!bid || seen.has(bid)) {
            tr = tr || state.tr
            tr.setNodeMarkup(pos, undefined, { ...node.attrs, bid: newID() })
          } else {
            seen.add(bid)
          }
          return true
        })
        return tr && tr.setMeta('addToHistory', false)
      },
    })]
  },
})

// MARK: The synced block

let options = { grouped: true, hideDone: false, tagLabel: '' }
// Synced blocks changed here and not yet seen back from the app: an update
// from the app leaves them alone until it matches, so a fresh edit is never
// overwritten by the version from before it was saved.
const dirty = new Set()
const reconcileKey = new PluginKey('schemaSyncedReconcile')

const MARKS = {
  bullet: () => Object.assign(document.createElement('span'), { className: 'synced-mark', textContent: '•' }),
  quote: () => Object.assign(document.createElement('span'), { className: 'synced-mark is-quote' }),
}

export const SyncedBlock = Node.create({
  name: 'syncedBlock',
  group: 'block',
  content: 'paragraph',
  isolating: true,
  defining: true,
  selectable: false,

  addAttributes() {
    const plain = (name, fallback = null) => ({ default: fallback, parseHTML: (el) => el.getAttribute(`data-${name}`), renderHTML: (a) => (a[name] == null ? {} : { [`data-${name}`]: a[name] }) })
    return {
      holderId: plain('holder'),
      bid: plain('bid'),
      kind: plain('kind', 'paragraph'),
      checked: { default: false, parseHTML: (el) => el.getAttribute('data-checked') === 'true', renderHTML: (a) => ({ 'data-checked': a.checked ? 'true' : 'false' }) },
      source: plain('source', ''),
      linkedPage: plain('linked'),
      number: plain('number'),
      after: plain('after'),
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-synced]' }]
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', mergeAttributes({ 'data-synced': '' }, HTMLAttributes), 0]
  },

  addNodeView() {
    return ({ node, getPos, editor }) => {
      let attrs = node.attrs
      const dom = document.createElement('div')
      dom.className = 'schema-synced'
      const lead = document.createElement('span')
      lead.className = 'synced-lead'
      lead.contentEditable = 'false'
      const content = document.createElement('div')
      content.className = 'synced-content'
      const trail = document.createElement('span')
      trail.className = 'synced-trail'
      trail.contentEditable = 'false'
      dom.append(lead, content, trail)

      const draw = () => {
        dom.className = `schema-synced kind-${attrs.kind}${attrs.checked ? ' is-done' : ''}`
        dom.dataset.bid = attrs.bid || ''
        lead.replaceChildren()
        if (attrs.kind === 'todo' || attrs.kind === 'task') {
          const box = document.createElement('button')
          box.type = 'button'
          box.className = 'synced-check'
          box.setAttribute('aria-pressed', attrs.checked ? 'true' : 'false')
          box.setAttribute('aria-label', attrs.checked ? 'Mark not done' : 'Complete')
          box.addEventListener('mousedown', (e) => e.preventDefault())
          box.addEventListener('click', () => {
            const pos = typeof getPos === 'function' ? getPos() : null
            if (pos == null) return
            editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { ...attrs, checked: !attrs.checked }))
          })
          lead.append(box)
        } else if (attrs.kind === 'numbered') {
          lead.append(Object.assign(document.createElement('span'), { className: 'synced-mark', textContent: `${attrs.number || 1}.` }))
        } else if (MARKS[attrs.kind]) {
          lead.append(MARKS[attrs.kind]())
        } else {
          lead.append(Object.assign(document.createElement('span'), { className: 'synced-mark' }))
        }
        trail.replaceChildren()
        if (attrs.linkedPage) trail.append(Object.assign(document.createElement('span'), { className: 'schema-task-link', textContent: `Task in ${attrs.linkedPage}` }))
        const where = document.createElement('span')
        where.className = 'synced-source'
        where.textContent = attrs.source || ''
        where.title = `This block lives in ${attrs.source}. Edits here show there too.`
        trail.append(where)
      }
      draw()
      return {
        dom,
        contentDOM: content,
        update(next) {
          if (next.type.name !== 'syncedBlock') return false
          attrs = next.attrs
          draw()
          return true
        },
        ignoreMutation: (m) => !content.contains(m.target),
        stopEvent: (e) => lead.contains(e.target) || trail.contains(e.target),
      }
    }
  },

  addKeyboardShortcuts() {
    const inSynced = (state) => {
      const { $from } = state.selection
      for (let d = $from.depth; d > 0; d--) {
        if ($from.node(d).type.name === 'syncedBlock') return { node: $from.node(d), pos: $from.before(d), depth: d }
      }
      return null
    }
    return {
      // A new block where this one lives, right after it, with the same tags.
      Enter: ({ editor }) => {
        const { state } = editor
        const found = inSynced(state)
        if (!found) return false
        const { node, pos } = found
        const chips = []
        node.firstChild.forEach((child) => {
          if (child.type.name === 'mention' && child.attrs.kind === 'tag') chips.push(child.type.create(child.attrs))
        })
        const content = chips.length ? [state.schema.text(' '), ...chips.flatMap((c, i) => (i ? [state.schema.text(' '), c] : [c]))] : []
        const kind = node.attrs.kind === 'heading' ? 'paragraph' : node.attrs.kind
        const bid = kind === 'task' ? `task:${newID()}` : newID()
        const block = node.type.create(
          { ...node.attrs, bid, kind, checked: false, linkedPage: null, after: node.attrs.bid, number: node.attrs.number ? Number(node.attrs.number) + 1 : null },
          state.schema.nodes.paragraph.create(null, content),
        )
        const at = pos + node.nodeSize
        const tr = state.tr.insert(at, block)
        tr.setSelection(TextSelection.create(tr.doc, at + 2))
        editor.view.dispatch(tr.scrollIntoView())
        return true
      },
      // Never merge into the block above; an empty one takes the tag off.
      Backspace: ({ editor }) => {
        const { state } = editor
        const { selection } = state
        const found = inSynced(state)
        if (!found || !selection.empty || selection.$from.parentOffset !== 0) return false
        const text = found.node.textContent.trim()
        const onlyTags = found.node.firstChild.childCount === 0 || (!text && found.node.firstChild.content.content.every((c) => c.type.name === 'mention' || /^\s*$/.test(c.text || '')))
        if (onlyTags) {
          const tr = state.tr.delete(found.pos, found.pos + found.node.nodeSize)
          editor.view.dispatch(tr)
        }
        return true
      },
      // Delete at the end of the block above a synced block does nothing.
      Delete: ({ editor }) => {
        const { state } = editor
        const { $from, empty } = state.selection
        if (!empty || $from.parentOffset !== $from.parent.content.size) return false
        if (inSynced(state)) return true
        if ($from.depth < 1) return false
        return state.doc.resolve($from.after(1)).nodeAfter?.type.name === 'syncedBlock'
      },
    }
  },

  addProseMirrorPlugins() {
    const editor = this.editor
    const bids = (doc) => {
      const map = new Map()
      doc.forEach((node) => { if (node.type.name === 'syncedBlock' && node.attrs.bid) map.set(node.attrs.bid, node.attrs) })
      return map
    }
    return [new Plugin({
      key: reconcileKey,
      state: {
        init: () => ({ fromApp: false }),
        apply: (tr) => ({ fromApp: !!tr.getMeta(reconcileKey) }),
      },
      // A synced block taken off this page by hand: the tag comes off it
      // where it lives. (Blocks the app removes are already gone there.)
      view: () => ({
        update(view, prev) {
          if (reconcileKey.getState(view.state).fromApp || prev.doc === view.state.doc) return
          const old = new Map()
          prev.doc.forEach((node) => { if (node.type.name === 'syncedBlock') old.set(node.attrs.bid, node) })
          view.state.doc.forEach((node) => {
            if (node.type.name === 'syncedBlock' && old.has(node.attrs.bid) && old.get(node.attrs.bid) !== node) dirty.add(node.attrs.bid)
          })
          const before = bids(prev.doc)
          if (before.size === 0) return
          const now = bids(view.state.doc)
          const removed = [...before.entries()].filter(([bid]) => !now.has(bid)).map(([bid, a]) => ({ holderId: a.holderId, bid, kind: a.kind, after: a.after }))
          if (removed.length) post({ type: 'syncedRemoved', items: removed })
        },
      }),
      props: {
        // "From Ideas" above each page's blocks when grouped by page.
        decorations(state) {
          if (!options.grouped) return null
          const widgets = []
          let last = null
          state.doc.forEach((node, pos) => {
            if (node.type.name !== 'syncedBlock') { last = null; return }
            if (node.attrs.source !== last) {
              const source = node.attrs.source
              widgets.push(Decoration.widget(pos, () => {
                const el = document.createElement('div')
                el.className = 'tagged-divider'
                el.contentEditable = 'false'
                const from = Object.assign(document.createElement('span'), { className: 'tagged-from', textContent: `From ${source}` })
                el.append(from, Object.assign(document.createElement('span'), { className: 'tagged-rule' }))
                return el
              }, { side: -1, key: `from:${source}:${pos}`, ignoreSelection: true }))
              last = source
            }
          })
          return DecorationSet.create(state.doc, widgets)
        },
      },
    })]
  },
})

// MARK: From the app

const sameContent = (node, block) => {
  try {
    return JSON.stringify(node.firstChild.content.toJSON() || []) === JSON.stringify(block.content || [])
  } catch (_) {
    return false
  }
}

const attrsOf = (b) => ({
  holderId: b.holderId, bid: b.bid, kind: b.kind, checked: !!b.checked, source: b.source || '',
  linkedPage: b.linkedPage || null, number: b.number == null ? null : String(b.number), after: null,
})

let shownKey = null

// The tag page's blocks from other pages, as they are now. Blocks change
// in place (the one being typed in is left alone), new ones are added, and
// ones no longer tagged leave. Grouped by page, they follow the pages' order.
export function setSyncedBlocks(editor, data, key) {
  options = { grouped: data?.grouped !== false, hideDone: !!data?.hideDone, tagLabel: data?.tagLabel || '' }
  document.body.classList.toggle('hides-done', options.hideDone)
  document.body.classList.toggle('is-tag-page', !!data)
  if (!data) return
  const { state } = editor
  const { schema } = state
  const blocks = data.blocks || []
  const wanted = new Map(blocks.map((b) => [b.bid, b]))
  const focused = editor.isFocused ? (() => {
    const { $from } = state.selection
    for (let d = $from.depth; d > 0; d--) if ($from.node(d).type.name === 'syncedBlock') return $from.node(d).attrs.bid
    return null
  })() : null
  const make = (b) => {
    let paragraph
    try {
      paragraph = schema.nodeFromJSON({ type: 'paragraph', content: b.content || [] })
    } catch (_) {
      paragraph = schema.nodes.paragraph.create()
    }
    return schema.nodes.syncedBlock.create(attrsOf(b), paragraph)
  }
  const tr = state.tr
  const fresh = shownKey !== key
  shownKey = key
  // Leave: no longer tagged here, or (when grouped) to be put back in order.
  const existing = []
  state.doc.forEach((node, pos) => { if (node.type.name === 'syncedBlock') existing.push({ node, pos }) })
  for (const { node, pos } of [...existing].reverse()) {
    const b = wanted.get(node.attrs.bid)
    if (!b && node.attrs.after) {
      // Made with Return here and not written back yet: keep it.
      continue
    }
    if (!b) tr.delete(tr.mapping.map(pos), tr.mapping.map(pos + node.nodeSize))
  }
  const present = new Map()
  tr.doc.forEach((node, pos) => { if (node.type.name === 'syncedBlock') present.set(node.attrs.bid, { node, pos }) })
  // Change in place.
  for (const b of blocks) {
    const here = present.get(b.bid)
    if (!here || b.bid === focused) continue
    const same = sameContent(here.node, b) && JSON.stringify({ ...here.node.attrs, after: null }) === JSON.stringify(attrsOf(b))
    if (same) { dirty.delete(b.bid); continue }
    // Changed here and not saved back yet: ours is newer.
    if (dirty.has(b.bid) && sameContent(here.node, b) === false && !here.node.attrs.after) continue
    {
      const pos = tr.mapping.map(here.pos)
      tr.replaceWith(pos, pos + here.node.nodeSize, make(b))
    }
  }
  // Add the new ones: after their page's last block when grouped, else at the end.
  for (const b of blocks) {
    let inDoc = false
    tr.doc.forEach((node) => { if (node.type.name === 'syncedBlock' && node.attrs.bid === b.bid) inDoc = true })
    if (inDoc) continue
    // Before the empty line the editor keeps at the end, so it stays last.
    const last = tr.doc.lastChild
    let at = tr.doc.content.size - (last && last.type.name === 'paragraph' && last.content.size === 0 ? last.nodeSize : 0)
    if (options.grouped) {
      let lastOfPage = null
      tr.doc.forEach((node, pos) => { if (node.type.name === 'syncedBlock' && node.attrs.source === b.source) lastOfPage = pos + node.nodeSize })
      if (lastOfPage !== null) at = lastOfPage
    }
    tr.insert(at, make(b))
  }
  // Grouped by page: the pages' order, once when the page opens or the
  // setting changes, so blocks don't jump while you type.
  if (options.grouped && fresh) {
    const order = new Map(blocks.map((b, i) => [b.bid, i]))
    const synced = []
    tr.doc.forEach((node, pos) => { if (node.type.name === 'syncedBlock') synced.push({ node, pos }) })
    const sorted = [...synced].sort((a, b) => (order.get(a.node.attrs.bid) ?? 1e9) - (order.get(b.node.attrs.bid) ?? 1e9))
    if (sorted.some((s, i) => s !== synced[i])) {
      const start = synced[0].pos
      for (const { node, pos } of [...synced].reverse()) tr.delete(pos, pos + node.nodeSize)
      tr.insert(start, sorted.map((s) => s.node))
    }
  }
  if (!tr.docChanged) {
    editor.view.dispatch(state.tr.setMeta(reconcileKey, true).setMeta('addToHistory', false))
    return
  }
  editor.view.dispatch(tr.setMeta(reconcileKey, true).setMeta('addToHistory', false))
}

export const regroup = () => { shownKey = null }
