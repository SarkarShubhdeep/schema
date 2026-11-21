// Schema's menu panel inside the editor (#78), styled like the native
// Schema menus (#83): rows with an optional glyph, a check or hint on the
// right, headers, separators and one level of submenu. ↑ ↓ move, Return
// or → chooses, ← closes a submenu, Esc closes.
//
// items: { title, glyph?, trail?, checked?, danger?, key?, run?, submenu? }
//        | { header } | { separator: true } | { footer }

let open = null // the root menu on screen, if any

export const isMenuOpen = () => open !== null

export function closeMenu() {
  if (!open) return
  const menu = open
  open = null
  menu.close()
}

// Keys for the open menu. Returns true when the menu used the key.
export function menuKeyDown(event) {
  if (!open) return false
  return open.key(event)
}

export function showMenu({ label, header, items, anchor, below = true, onClose }) {
  closeMenu()
  open = new Panel({ label, header, items, anchor, below, onClose })
  return open
}

// Changes the items of the open menu, keeping it where it is (the / menu
// as the query changes).
export function updateMenu(items) {
  if (open) open.setItems(items)
}

class Panel {
  constructor({ label, header, items, anchor, below, onClose, parent }) {
    this.label = label
    this.header = header
    this.anchor = anchor
    this.below = below
    this.onClose = onClose
    this.parent = parent
    this.child = null
    this.el = document.createElement('div')
    this.el.className = 'schema-menu'
    this.el.setAttribute('role', 'menu')
    this.el.setAttribute('aria-label', label)
    this.el.style.left = '0px'
    this.el.style.top = '0px'
    // Keep the editor's caret and focus while the menu is used.
    this.el.addEventListener('mousedown', (e) => e.preventDefault())
    document.body.appendChild(this.el)
    this.setItems(items)
  }

  setItems(items) {
    this.items = items
    this.choosable = items.filter((i) => i.title)
    this.selected = Math.max(0, this.choosable.findIndex((i) => i.selected))
    this.render()
    this.place()
  }

  render() {
    this.el.textContent = ''
    if (this.header) this.el.appendChild(this.headerRow(this.header))
    this.rows = []
    for (const item of this.items) {
      if (item.header) { this.el.appendChild(this.headerRow(item.header)); continue }
      if (item.footer) {
        const foot = document.createElement('div')
        foot.className = 'schema-menu-footer'
        foot.textContent = item.footer
        foot.setAttribute('aria-hidden', 'true')
        this.el.appendChild(foot)
        continue
      }
      if (item.separator) {
        const sep = document.createElement('div')
        sep.className = 'schema-menu-separator'
        sep.setAttribute('role', 'separator')
        this.el.appendChild(sep)
        continue
      }
      const index = this.choosable.indexOf(item)
      const row = document.createElement('div')
      row.className = 'schema-menu-item' + (item.danger ? ' is-danger' : '')
      row.setAttribute('role', 'menuitem')
      row.id = `schema-menu-${Math.random().toString(36).slice(2)}`
      if (item.submenu) row.setAttribute('aria-haspopup', 'menu')
      if (item.glyph) {
        const glyph = document.createElement('span')
        glyph.className = 'schema-menu-glyph'
        glyph.textContent = item.glyph
        glyph.setAttribute('aria-hidden', 'true')
        row.appendChild(glyph)
      }
      const title = document.createElement('span')
      title.className = 'schema-menu-title'
      title.textContent = item.title
      row.appendChild(title)
      const trail = item.checked ? '✓' : (item.submenu ? '›' : (item.trail || ''))
      if (trail) {
        const t = document.createElement('span')
        t.className = 'schema-menu-trail'
        t.textContent = trail
        t.setAttribute('aria-hidden', item.checked ? 'false' : 'true')
        row.appendChild(t)
      }
      if (item.checked) row.setAttribute('aria-checked', 'true')
      row.addEventListener('mousemove', () => {
        if (this.selected !== index) { this.selected = index; this.highlight() }
        if (item.submenu && !this.child) this.openSubmenu(item)
        if (!item.submenu && this.child) this.closeSubmenu()
      })
      row.addEventListener('click', () => this.choose(item))
      this.rows.push(row)
      this.el.appendChild(row)
    }
    if (this.choosable.length === 0) {
      const empty = document.createElement('div')
      empty.className = 'schema-menu-empty'
      empty.textContent = 'No matches'
      this.el.insertBefore(empty, this.el.querySelector('.schema-menu-footer'))
    }
    this.highlight()
  }

  headerRow(text) {
    const h = document.createElement('div')
    h.className = 'schema-menu-header'
    h.textContent = text
    return h
  }

  highlight() {
    this.rows.forEach((row, i) => row.classList.toggle('is-selected', i === this.selected))
    const row = this.rows[this.selected]
    if (row) {
      this.el.setAttribute('aria-activedescendant', row.id)
      // Scroll the menu only, never the page.
      const top = row.offsetTop
      const bottom = top + row.offsetHeight
      if (top < this.el.scrollTop) this.el.scrollTop = top - 6
      else if (bottom > this.el.scrollTop + this.el.clientHeight) this.el.scrollTop = bottom - this.el.clientHeight + 6
    }
  }

  // Below the anchor rect, or above it when there is no room below.
  place() {
    const a = this.anchor
    const rect = this.el.getBoundingClientRect()
    const margin = 8
    let left = Math.min(a.left, window.innerWidth - rect.width - margin)
    let top = this.below ? a.bottom + 4 : a.top
    if (top + rect.height > window.innerHeight - margin) {
      top = this.below ? a.top - rect.height - 4 : window.innerHeight - rect.height - margin
    }
    this.el.style.left = `${Math.max(margin, left) + window.scrollX}px`
    this.el.style.top = `${Math.max(margin, top) + window.scrollY}px`
  }

  openSubmenu(item) {
    this.closeSubmenu()
    const row = this.rows[this.choosable.indexOf(item)]
    const r = row.getBoundingClientRect()
    const panel = this.el.getBoundingClientRect()
    this.child = new Panel({
      label: item.title,
      header: item.title,
      items: item.submenu(),
      anchor: { left: panel.right + 6, right: panel.right + 6, top: r.top - 6, bottom: r.top - 6 },
      below: false,
      parent: this,
    })
    // A submenu sits beside its row, not below it.
    this.child.el.style.top = `${Math.max(8, r.top - 6 - (this.child.header ? 26 : 0)) + window.scrollY}px`
  }

  closeSubmenu() {
    if (this.child) { this.child.el.remove(); this.child = null }
  }

  choose(item) {
    if (!item) return
    if (item.submenu) { this.openSubmenu(item); this.child.selected = Math.max(0, this.child.selected); this.child.highlight(); return }
    closeMenu()
    item.run?.()
  }

  key(event) {
    if (this.child) {
      if (event.key === 'ArrowLeft' || event.key === 'Escape') { this.closeSubmenu(); return true }
      return this.child.key(event)
    }
    const count = this.choosable.length
    switch (event.key) {
      case 'ArrowDown':
        if (count) { this.selected = (this.selected + 1) % count; this.highlight() }
        return true
      case 'ArrowUp':
        if (count) { this.selected = (this.selected - 1 + count) % count; this.highlight() }
        return true
      case 'Enter':
      case 'Tab':
        if (!count) return false
        this.choose(this.choosable[this.selected])
        return true
      case 'ArrowRight': {
        const item = this.choosable[this.selected]
        if (item?.submenu) { this.choose(item); return true }
        return false
      }
      case 'ArrowLeft':
        if (this.parent) { this.parent.closeSubmenu(); return true }
        return false
      case 'Escape':
        closeMenu()
        return true
      default: {
        // Shortcuts shown on the right, e.g. ⌫ for Delete, ⌘D for Duplicate.
        const shortcut = this.choosable.find((i) => i.key && i.key(event))
        if (shortcut) { this.choose(shortcut); return true }
        return false
      }
    }
  }

  close() {
    this.closeSubmenu()
    this.el.remove()
    this.onClose?.()
  }
}

// A click anywhere else closes the menu. The handle toggles its own menu.
document.addEventListener('mousedown', (event) => {
  if (open && !event.target.closest?.('.schema-menu, .schema-handle')) closeMenu()
}, true)
window.addEventListener('blur', () => closeMenu())
