// Pasting Markdown (#79): text copied from a Markdown file or another
// Markdown app pastes as headings, lists, to-dos, quotes, code and marks,
// not as the raw # and ** characters. Rich text from other apps (HTML with
// real headings, lists or bold) pastes as ProseMirror reads it. ⇧⌘V pastes
// plain text, and nothing is read as Markdown inside a code block.

const BLOCK = /^(#{1,6} |[-*+] |\d{1,9}[.)] |> |```|~~~|[-*+] \[[ xX]\] |(---|\*\*\*|___)\s*$)/m
const INLINE = /\*\*[^*\n]+\*\*|~~[^~\n]+~~|`[^`\n]+`|\[[^\]\n]+\]\([^)\s]+\)|(^|[^\w*])\*[^*\s][^*\n]*\*(?![\w*])|(^|[^\w])_[^_\s][^_\n]*_(?!\w)/

export const looksLikeMarkdown = (text) => BLOCK.test(text) || INLINE.test(text)

// HTML that already says what is a heading, list or mark.
const RICH_HTML = /<(h[1-6]|ul|ol|li|strong|b|em|i|blockquote|pre|table|a\s)[\s>]/i

export function markdownPaste(editor) {
  return (view, event) => {
    const data = event.clipboardData
    if (!data || view.input?.shiftKey) return false
    if (editor.isActive('codeBlock')) return false
    const text = data.getData('text/plain')
    if (!text || !looksLikeMarkdown(text)) return false
    const html = data.getData('text/html')
    if (html && RICH_HTML.test(html)) return false
    const doc = editor.markdown?.parse(text)
    if (!doc?.content?.length) return false
    // One line of text joins the line it is pasted into.
    const single = doc.content.length === 1 && doc.content[0].type === 'paragraph'
    const content = single ? (doc.content[0].content || []) : doc.content
    editor.chain().focus().insertContent(content).scrollIntoView().run()
    return true
  }
}
