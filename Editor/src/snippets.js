// Snippets (#101): your own triggers, like ;email, that turn into their text
// the moment the trigger is typed in full. The text can span lines and use
// markdown, so ;meet can drop in a heading and three to-dos. {date}, {time}
// and {cursor} fill in when it's used. Never inside code.
//
// Backspace or ⌘Z right after puts the trigger back: a snippet is an input
// rule, so TipTap's undoInputRule takes it back like any other replacement.
//
// The app sends the list with setSnippets([{ trigger, text }]) from Settings.

import { Extension, InputRule } from '@tiptap/core'
import { TextSelection } from '@tiptap/pm/state'

let snippets = []
export const setSnippets = (list) => {
  // Longest first, so ;meeting wins over ;meet.
  snippets = (Array.isArray(list) ? list : [])
    .filter((s) => s && typeof s.trigger === 'string' && s.trigger.trim() && typeof s.text === 'string')
    .sort((a, b) => b.trigger.length - a.trigger.length)
}

const CURSOR = ''

// A trigger fires at the start of a line or after a space or punctuation, so
// "email" as a trigger doesn't fire inside "gmail". Triggers that start with
// a symbol, like ;email, fire anywhere.
const startsWithSymbol = (trigger) => !/^[\p{L}\p{N}]/u.test(trigger)
export function findSnippet(text) {
  for (const snippet of snippets) {
    if (!text.endsWith(snippet.trigger)) continue
    const index = text.length - snippet.trigger.length
    const before = index > 0 ? text[index - 1] : ''
    if (!startsWithSymbol(snippet.trigger) && before && /[\p{L}\p{N}_]/u.test(before)) continue
    return { index, text: snippet.trigger, data: { snippet } }
  }
  return null
}

// {date} → Mon 23 Nov, {time} → 2:30 PM, {cursor} → where the caret lands.
export function fill(text, now = new Date()) {
  const date = now.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short' }).replace(',', '')
  const time = now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
  let filled = text.replaceAll('{date}', date).replaceAll('{time}', time)
  // Only the first {cursor} counts.
  const at = filled.indexOf('{cursor}')
  filled = filled.replaceAll('{cursor}', '')
  if (at >= 0) filled = filled.slice(0, at) + CURSOR + filled.slice(at)
  return filled
}

export const Snippets = Extension.create({
  name: 'schemaSnippets',
  // Before Typography's rules, so a snippet wins over a replacement.
  priority: 1001,

  addInputRules() {
    const editor = this.editor
    return [
      new InputRule({
        find: (text) => (snippets.length ? findSnippet(text) : null),
        handler: ({ state, range, match, commands }) => {
          const snippet = match.data?.snippet
          if (!snippet) return null
          const text = fill(snippet.text)
          const { tr } = state
          if (!text.includes('\n')) {
            tr.insertText(text, range.from, range.to)
          } else {
            // Several lines: read them as markdown, so "- [ ] " lines are to-dos.
            const doc = editor.markdown?.parse(text)
            const blocks = doc?.content?.length ? doc.content : null
            if (blocks) commands.insertContentAt(range, blocks)
            else tr.insertText(text, range.from, range.to)
          }
          // Put the caret where {cursor} was, and take the marker out.
          let caret = null
          tr.doc.nodesBetween(range.from, Math.min(tr.doc.content.size, range.from + text.length + 64), (node, pos) => {
            if (caret !== null || !node.isText) return caret === null
            const i = node.text.indexOf(CURSOR)
            if (i >= 0) caret = pos + i
            return false
          })
          if (caret !== null) {
            tr.delete(caret, caret + 1)
            tr.setSelection(TextSelection.create(tr.doc, caret))
          }
        },
      }),
    ]
  },
})
