//
//  ConfigureSheetController.swift
//  RetroSVR · RetroSVR
//
//  The Options sheet, styled like the Windows settings dialog: green monospace on charcoal.
//

import AppKit
import RetroSVRCore

/// Builds and runs the configure sheet that System Settings shows from "Options…".
///
/// The sheet edits a copy of the settings and hands it to `onSave` only on OK.
@MainActor
final class ConfigureSheetController: NSObject {
    /// The sheet to return from `ScreenSaverView.configureSheet`.
    let window: NSWindow

    private let onSave: (SaverSettings) -> Void
    private let effectPopup = NSPopUpButton()
    private let durationSlider: NSSlider
    private let scaleSlider: NSSlider
    private let frameRateSlider: NSSlider
    private let durationValue = NSTextField(labelWithString: "")
    private let scaleValue = NSTextField(labelWithString: "")
    private let frameRateValue = NSTextField(labelWithString: "")
    private let smoothCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let soundCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    private static let green = RetroStyle.green
    private static let background = RetroStyle.background
    private static let font = RetroStyle.font
    /// Popup item order: "All Effects" first, then one item per ``EffectKind``.
    private static let selections: [EffectSelection] = [.cycleAll] + EffectKind.allCases.map { .single($0) }

    init(settings: SaverSettings, onSave: @escaping (SaverSettings) -> Void) {
        self.onSave = onSave
        durationSlider = Self.makeSlider(SaverSettings.effectDurationRange, value: settings.effectDuration, ticks: 0)
        scaleSlider = Self.makeSlider(SaverSettings.pixelScaleRange, value: settings.pixelScale, ticks: 8)
        frameRateSlider = Self.makeSlider(SaverSettings.frameRateRange, value: settings.frameRate, ticks: 10)
        window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        // Swift owns the window; AppKit's extra release on close would over-release it.
        window.isReleasedWhenClosed = false
        super.init()

        effectPopup.addItems(withTitles: ["All Effects (Cycle)"] + EffectKind.allCases.map(\.displayName))
        effectPopup.selectItem(at: Self.selections.firstIndex(of: settings.selection) ?? 0)
        effectPopup.font = Self.font
        smoothCheckbox.state = settings.smoothTransitions ? .on : .off
        soundCheckbox.state = settings.soundEnabled ? .on : .off
        styleCheckbox(smoothCheckbox, title: "Smooth transitions")
        styleCheckbox(soundCheckbox, title: "Dissolver sound")

        for control: NSControl in [effectPopup, durationSlider, scaleSlider, frameRateSlider] {
            control.target = self
            control.action = #selector(controlChanged(_:))
        }

        buildWindow()
        refreshLabels()
    }

    // MARK: - Layout

    private func buildWindow() {
        let title = NSTextField(labelWithString: "RETRO 8-BIT SCREENSAVER")
        title.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        title.textColor = Self.green

        for valueLabel in [durationValue, scaleValue, frameRateValue] {
            valueLabel.font = Self.font
            valueLabel.textColor = Self.green
            valueLabel.widthAnchor.constraint(equalToConstant: 64).isActive = true
        }
        for slider in [durationSlider, scaleSlider, frameRateSlider] {
            slider.widthAnchor.constraint(equalToConstant: 240).isActive = true
        }

        let grid = NSGridView(views: [
            [label("Effect:"), effectPopup, NSGridCell.emptyContentView],
            [label("Effect duration:"), durationSlider, durationValue],
            [label("Pixel scale:"), scaleSlider, scaleValue],
            [label("Frame rate:"), frameRateSlider, frameRateValue],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.rowAlignment = .none
        grid.column(at: 0).xPlacement = .trailing
        for row in 0..<grid.numberOfRows {
            grid.row(at: row).yPlacement = .center
        }
        grid.cell(atColumnIndex: 1, rowIndex: 0).xPlacement = .fill

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let ok = NSButton(title: "OK", target: self, action: #selector(ok(_:)))
        ok.keyEquivalent = "\r"
        let version = label("v\(Bundle(for: Self.self).object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
        version.textColor = Self.green.withAlphaComponent(0.5)
        let buttons = NSStackView(views: [version, NSView(), cancel, ok])
        buttons.distribution = .fill

        let checkboxes = NSStackView(views: [smoothCheckbox, soundCheckbox])
        checkboxes.orientation = .vertical
        checkboxes.alignment = .leading

        let content = NSStackView(views: [title, grid, checkboxes, buttons])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        content.setCustomSpacing(24, after: checkboxes)
        buttons.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true

        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Self.background
        window.contentView = content
        window.setContentSize(content.fittingSize)
        window.defaultButtonCell = ok.cell as? NSButtonCell
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = Self.font
        field.textColor = Self.green
        return field
    }

    private func styleCheckbox(_ checkbox: NSButton, title: String) {
        checkbox.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: Self.green, .font: Self.font]
        )
    }

    private static func makeSlider(_ range: ClosedRange<Int>, value: Int, ticks: Int) -> NSSlider {
        let slider = NSSlider(
            value: Double(value),
            minValue: Double(range.lowerBound),
            maxValue: Double(range.upperBound),
            target: nil,
            action: nil
        )
        if ticks > 0 {
            slider.numberOfTickMarks = ticks
            slider.allowsTickMarkValuesOnly = true
        }
        return slider
    }

    // MARK: - Actions

    private var currentSettings: SaverSettings {
        SaverSettings(
            selection: Self.selections[max(0, effectPopup.indexOfSelectedItem)],
            effectDuration: Int(durationSlider.doubleValue.rounded()),
            pixelScale: Int(scaleSlider.doubleValue.rounded()),
            frameRate: Int(frameRateSlider.doubleValue.rounded()),
            smoothTransitions: smoothCheckbox.state == .on,
            soundEnabled: soundCheckbox.state == .on
        )
    }

    private func refreshLabels() {
        let settings = currentSettings
        durationValue.stringValue = "\(settings.effectDuration)s"
        scaleValue.stringValue = "\(settings.pixelScale)x"
        frameRateValue.stringValue = "\(settings.frameRate) FPS"
        // Duration and transitions only matter while cycling.
        let cycling = settings.selection == .cycleAll
        durationSlider.isEnabled = cycling
        smoothCheckbox.isEnabled = cycling
    }

    @objc private func controlChanged(_ sender: Any?) {
        refreshLabels()
    }

    @objc private func ok(_ sender: Any?) {
        onSave(currentSettings)
        close()
    }

    @objc private func cancel(_ sender: Any?) {
        close()
    }

    private func close() {
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }
}
