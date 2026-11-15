//
//  SchemaMotion.swift
//  Schema
//
//  Motion from the design system: 180ms ease for hover and selection, 320ms
//  smooth for completing, moving and reordering. Respect Reduce Motion by
//  passing the environment value to `animation(_:reduceMotion:)`.
//

import SwiftUI

enum SchemaMotion {
    /// Hover, selection and small state changes.
    static let fast = Animation.easeInOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.25)
    /// Completing, moving and reordering tasks; panels opening and closing.
    static let smooth = Animation.smooth(duration: 0.32)
    /// The checkbox press.
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)

    /// Returns `nil` (no movement) when Reduce Motion is on.
    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
