//
//  BlockTextView.swift
//  Schema
//
//  One native line of editable text: an NSTextView that reports Return,
//  Backspace at the start and arrows that leave it, grows with its text, and
//  takes the caret when asked. Page titles use it. It began as a block of
//  the old block editor (#38), which TipTap replaced (#82).
//

import AppKit
import SwiftUI

/// Where the caret goes.
enum CaretPlacement: Equatable {
    case start
    case end
    /// UTF-16 offset, as NSTextView counts.
    case offset(Int)
    /// Select all the text, e.g. to rename a page title.
    case all
}

/// A request to move the caret. `token` changes on every request, so asking
/// for the same field twice still moves the caret.
struct BlockFocusRequest: Equatable {
    let blockID: UUID
    let caret: CaretPlacement
    let token = UUID()
}

extension NSFont {
    /// Satoshi, the text face.
    static func schemaText(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        schemaFont(family: SchemaFont.textFamily, size: size, weight: weight)
    }

    /// Space Grotesk, the display face.
    static func schemaDisplay(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        schemaFont(family: SchemaFont.displayFamily, size: size, weight: weight)
    }

    private static func schemaFont(family: String, size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: weight],
        ])
        return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

struct BlockTextStyle: Equatable {
    var font: NSFont
    var color: NSColor
    var lineHeight: CGFloat
    var isStruckThrough = false
    var isItalic = false
    /// Letter spacing in points, like SwiftUI's `tracking`.
    var kern: CGFloat = 0
}

struct BlockTextView: NSViewRepresentable {
    let text: String
    let style: BlockTextStyle
    var placeholder: String = ""
    /// Applied once per token: put the caret in this view.
    let focusRequest: BlockFocusRequest?
    let blockID: UUID
    /// While the / menu is open on this line, ↑ ↓ Return and Esc drive it.
    var isMenuOpen = false

    var onTextChange: (String) -> Void
    var onReturn: (Int) -> Void
    var onBackspaceAtStart: () -> Void
    var onArrowOut: (_ forward: Bool) -> Void
    var onFocusChange: (Bool) -> Void
    var onMenuMove: (Int) -> Void = { _ in }
    var onMenuChoose: () -> Void = {}
    var onMenuDismiss: () -> Void = {}
    var onTurnInto: () -> Void = {}
    /// Esc with no menu open; nil leaves Esc to the text view.
    var onEscape: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> BlockNSTextView {
        let view = BlockNSTextView()
        view.delegate = context.coordinator
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.focusRingType = .none
        view.setAccessibilityRole(.textArea)
        view.onFocusChange = { context.coordinator.parent.onFocusChange($0) }
        view.onTurnInto = { context.coordinator.parent.onTurnInto() }
        view.string = text
        apply(style, to: view)
        return view
    }

    func updateNSView(_ view: BlockNSTextView, context: Context) {
        context.coordinator.parent = self
        if view.string != text, !view.hasMarkedText() {
            view.string = text
        }
        if view.blockStyle != style || view.placeholder != placeholder {
            apply(style, to: view)
        }
        if let request = focusRequest, request.blockID == blockID,
           request.token != context.coordinator.appliedToken {
            context.coordinator.appliedToken = request.token
            DispatchQueue.main.async {
                guard let window = view.window else { return }
                window.makeFirstResponder(view)
                let length = (view.string as NSString).length
                let location: Int
                switch request.caret {
                case .start: location = 0
                case .end: location = length
                case .offset(let offset): location = min(max(offset, 0), length)
                case .all:
                    view.setSelectedRange(NSRange(location: 0, length: length))
                    return
                }
                view.setSelectedRange(NSRange(location: location, length: 0))
                view.scrollRangeToVisible(NSRange(location: location, length: 0))
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: BlockNSTextView, context: Context) -> CGSize? {
        // Measure a copy of the text: SwiftUI probes several widths, and
        // resizing the live text container for a probe would leave it
        // wrapping at the wrong width.
        let width = proposal.width ?? 400
        guard width > 0, let storage = view.textStorage else { return nil }
        let text = NSAttributedString(attributedString: storage)
        var height = text.length == 0 ? 0 : text.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height
        if view.string.hasSuffix("\n") { height += style.lineHeight }
        return CGSize(width: width, height: max(ceil(height), style.lineHeight))
    }

    private func apply(_ style: BlockTextStyle, to view: BlockNSTextView) {
        view.blockStyle = style
        view.placeholder = placeholder
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight
        var font = style.font
        if style.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        // Center the glyphs in the fixed line height.
        let offset = (style.lineHeight - (font.ascender - font.descender)) / 2
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.color,
            .paragraphStyle: paragraph,
            .baselineOffset: max(0, offset / 2),
            .kern: style.kern,
        ]
        if style.isStruckThrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = style.color
        }
        view.font = font
        view.textColor = style.color
        view.defaultParagraphStyle = paragraph
        view.typingAttributes = attributes
        view.insertionPointColor = NSColor(SchemaTheme.ink)
        if let storage = view.textStorage {
            storage.beginEditing()
            storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }
        view.needsDisplay = true
        view.invalidateIntrinsicContentSize()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockTextView
        var appliedToken: UUID?

        init(_ parent: BlockTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.onTextChange(view.string)
            view.invalidateIntrinsicContentSize()
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let range = textView.selectedRange()
            let length = (textView.string as NSString).length
            if parent.isMenuOpen {
                switch selector {
                case #selector(NSResponder.moveUp(_:)):
                    parent.onMenuMove(-1)
                    return true
                case #selector(NSResponder.moveDown(_:)):
                    parent.onMenuMove(1)
                    return true
                case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
                    parent.onMenuChoose()
                    return true
                case #selector(NSResponder.cancelOperation(_:)):
                    parent.onMenuDismiss()
                    return true
                default:
                    break
                }
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) || selector == #selector(NSTextView.complete(_:)),
               let onEscape = parent.onEscape {
                onEscape()
                return true
            }
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onReturn(range.location)
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                guard range.location == 0, range.length == 0 else { return false }
                parent.onBackspaceAtStart()
                return true
            case #selector(NSResponder.moveUp(_:)):
                guard range.length == 0, isOnFirstLine(textView) else { return false }
                parent.onArrowOut(false)
                return true
            case #selector(NSResponder.moveDown(_:)):
                guard range.length == 0, isOnLastLine(textView) else { return false }
                parent.onArrowOut(true)
                return true
            case #selector(NSResponder.moveLeft(_:)):
                guard range.location == 0, range.length == 0 else { return false }
                parent.onArrowOut(false)
                return true
            case #selector(NSResponder.moveRight(_:)):
                guard range.location == length, range.length == 0 else { return false }
                parent.onArrowOut(true)
                return true
            default:
                return false
            }
        }

        private func caretLineRect(_ textView: NSTextView) -> NSRect? {
            guard let layout = textView.layoutManager, let container = textView.textContainer else { return nil }
            let length = (textView.string as NSString).length
            if length == 0 { return .zero }
            let location = textView.selectedRange().location
            if location >= length {
                // After the last character: the extra line fragment if the text ends in a newline.
                let extra = layout.extraLineFragmentRect
                if extra.height > 0 { return extra }
                let glyph = layout.glyphIndexForCharacter(at: length - 1)
                return layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            }
            let glyph = layout.glyphIndexForCharacter(at: location)
            _ = container
            return layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }

        private func isOnFirstLine(_ textView: NSTextView) -> Bool {
            guard let rect = caretLineRect(textView) else { return true }
            return rect.minY < 1
        }

        private func isOnLastLine(_ textView: NSTextView) -> Bool {
            guard let rect = caretLineRect(textView),
                  let layout = textView.layoutManager,
                  let container = textView.textContainer else { return true }
            let used = layout.usedRect(for: container)
            return rect.maxY >= used.maxY - 1
        }
    }
}

final class BlockNSTextView: NSTextView {
    var blockStyle: BlockTextStyle?
    var placeholder = "" {
        didSet { if oldValue != placeholder { needsDisplay = true } }
    }
    var onFocusChange: ((Bool) -> Void)?
    var onTurnInto: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    /// ⌘/ opens the Turn into menu for this line.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "/" {
            onTurnInto?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            onFocusChange?(true)
            needsDisplay = true
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChange?(false)
            needsDisplay = true
        }
        return resigned
    }

    /// Shows the placeholder only on the empty block being edited.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty, window?.firstResponder === self,
              let style = blockStyle else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight
        let offset = (style.lineHeight - (style.font.ascender - style.font.descender)) / 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            // inkMuted: placeholder hints are read, so they need 4.5:1 (#46).
            .foregroundColor: NSColor(SchemaTheme.inkMuted),
            .paragraphStyle: paragraph,
            .baselineOffset: max(0, offset / 2),
            .kern: style.kern,
        ]
        NSAttributedString(string: placeholder, attributes: attributes)
            .draw(in: NSRect(x: 0, y: 0, width: bounds.width, height: style.lineHeight))
    }
}
