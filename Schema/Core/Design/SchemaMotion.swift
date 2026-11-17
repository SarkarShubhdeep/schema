//
//  SchemaMotion.swift
//  Schema
//
//  Motion from the design system, in one place (#44).
//
//  - `fast` (180ms ease): hover, press, selection and colour changes.
//  - `smooth` (320ms): the one timing for anything that moves: panels,
//    rows, reordering, completing.
//  - `appear` (320ms): dialogs, the selection toolbar and other things that
//    come and go.
//
//  Reduce Motion is read here, so call sites don't have to: `smooth` and
//  `spring` become instant, `appear` becomes a short fade, and `moving(_:)`
//  turns slide transitions into fades.
//

import AppKit
import SwiftUI

enum SchemaMotion {
    /// Hover, press, selection and colour changes. Kept with Reduce Motion,
    /// since nothing moves.
    static var fast: Animation { .easeInOut(duration: 0.18 * pace) }

    /// Panels, rows, reordering, completing. Instant with Reduce Motion.
    static var smooth: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.32 * pace)
    }

    /// Dialogs and toolbars appearing. A short fade with Reduce Motion.
    static var appear: Animation {
        reduceMotion ? fast : .smooth(duration: 0.32 * pace)
    }

    /// The checkbox press. None with Reduce Motion.
    static var spring: Animation? {
        reduceMotion ? nil : .spring(response: 0.32 * pace, dampingFraction: 0.86)
    }

    /// A transition that slides or scales; a plain fade with Reduce Motion.
    static func moving(_ transition: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }

    /// For something that replaces a sliding panel (the floating sidebar
    /// bar): it comes in once the panel is mostly out of the way, and leaves
    /// quickly before the panel slides back over it.
    static func followingPanel(_ transition: AnyTransition) -> AnyTransition {
        let delayed = reduceMotion ? fast : Animation.smooth(duration: 0.24 * pace).delay(0.16 * pace)
        return .asymmetric(
            insertion: moving(transition).animation(delayed),
            removal: AnyTransition.opacity.animation(.easeOut(duration: 0.1 * pace))
        )
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 1 normally; `-SchemaDemoSlowMotion` slows everything down eightfold
    /// in Debug builds so motion can be checked frame by frame.
    private static let pace: Double = {
        #if DEBUG
        return CommandLine.arguments.contains("-SchemaDemoSlowMotion") ? 8 : 1
        #else
        return 1
        #endif
    }()
}
