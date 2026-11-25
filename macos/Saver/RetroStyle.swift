//
//  RetroStyle.swift
//  RetroSVR · RetroSVR
//
//  The green-on-charcoal look shared by the Options sheet and the app's on-screen hints.
//

import AppKit

/// Colours and fonts matching the Windows settings dialog.
@MainActor
enum RetroStyle {
    /// Phosphor green used for text and outlines.
    static let green = NSColor(srgbRed: 0, green: 1, blue: 0.5, alpha: 1)
    /// Charcoal window background.
    static let background = NSColor(srgbRed: 30 / 255, green: 30 / 255, blue: 35 / 255, alpha: 1)
    /// Body text.
    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
}
