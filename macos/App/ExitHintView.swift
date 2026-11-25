//
//  ExitHintView.swift
//  RetroSVRApp · RetroSVR
//
//  The "[ESC] or [SPACE] to exit" banner shown over the app's full-screen saver.
//

import AppKit

/// A translucent banner with keycap-style labels telling the viewer how to leave full screen.
///
/// The app's full-screen mode only ends on Escape or Space, unlike the system saver which
/// ends on any input, so the keys are spelled out on screen.
@MainActor
final class ExitHintView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        layer?.cornerRadius = 12
        layer?.borderColor = RetroStyle.green.withAlphaComponent(0.35).cgColor
        layer?.borderWidth = 1

        let stack = NSStackView(views: [
            Self.text("PRESS"),
            Self.keyCap("ESC"),
            Self.text("OR"),
            Self.keyCap("SPACE"),
            Self.text("TO EXIT"),
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Press Escape or Space to exit full screen")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The banner is information only; clicks pass through to the saver underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private static let hintFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)

    private static func text(_ string: String) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.font = hintFont
        field.textColor = RetroStyle.green.withAlphaComponent(0.8)
        return field
    }

    /// A label drawn as a keyboard key: outlined, rounded, with a heavier bottom edge.
    private static func keyCap(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .monospacedSystemFont(ofSize: 15, weight: .bold)
        label.textColor = RetroStyle.green
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let cap = NSView()
        cap.wantsLayer = true
        cap.layer?.backgroundColor = RetroStyle.background.cgColor
        cap.layer?.borderColor = RetroStyle.green.cgColor
        cap.layer?.borderWidth = 2
        cap.layer?.cornerRadius = 6
        cap.layer?.shadowColor = RetroStyle.green.cgColor
        cap.layer?.shadowOpacity = 0.6
        cap.layer?.shadowRadius = 0
        cap.layer?.shadowOffset = CGSize(width: 0, height: -3)
        cap.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cap.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: cap.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: cap.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: cap.bottomAnchor, constant: -6),
            cap.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
        return cap
    }
}
