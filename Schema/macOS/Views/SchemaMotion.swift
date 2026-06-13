//
//  SchemaMotion.swift
//  Schema
//

import SwiftUI

enum SchemaMotion {
    static let fast = Animation.easeInOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let smooth = Animation.smooth(duration: 0.32)
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
}
