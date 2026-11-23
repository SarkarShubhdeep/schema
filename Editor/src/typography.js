// Replacements as you type (#99). Satoshi has no arrow ligatures, so the
// characters themselves are replaced: -> →, <- ←, <-> ↔, => ⇒, <=> ⇔,
// != ≠, >= ≥, <= ≤, ... …, -- —, +/- ±, (c) ©, (tm) ™, and curly quotes.
// Built on TipTap's Typography extension; never inside code.
//
// Backspace or ⌘Z right after puts back what was typed. Settings can turn
// it all off (setTypography), which the app sends when it changes.

import { InputRule, textInputRule } from '@tiptap/core'
import { Typography } from '@tiptap/extension-typography'

let enabled = true
export const setTypography = (on) => {
  enabled = on !== false
}

const extra = [
  // Not at the start of a line or after another "-": that is on its way to
  // "---", a divider.
  textInputRule({ find: /[^\s-] ?(--)$/, replace: '—' }),
  textInputRule({ find: /←>$/, replace: '↔' }),
  textInputRule({ find: /≤>$/, replace: '⇔' }),
  textInputRule({ find: /=>$/, replace: '⇒' }),
  textInputRule({ find: />=$/, replace: '≥' }),
  textInputRule({ find: /<=$/, replace: '≤' }),
]

export const SchemaTypography = Typography.configure({
  // Off: ones that get in the way of ordinary writing, like "(a) (b) (c)"
  // lists, "1/2" in dates, "2x3", and "<<" or "^2" in technical notes.
  emDash: false,
  registeredTrademark: false,
  servicemark: false,
  oneHalf: false,
  oneQuarter: false,
  threeQuarters: false,
  multiplication: false,
  superscriptTwo: false,
  superscriptThree: false,
  laquo: false,
  raquo: false,
}).extend({
  // Above the history keymap, so ⌘Z takes back the replacement first.
  priority: 1000,

  addInputRules() {
    return [...(this.parent?.() ?? []), ...extra].map(
      (rule) => new InputRule({ find: rule.find, handler: (props) => (enabled ? rule.handler(props) : null) }),
    )
  },

  addKeyboardShortcuts() {
    return {
      'Mod-z': ({ editor }) => editor.commands.undoInputRule(),
    }
  },
})
