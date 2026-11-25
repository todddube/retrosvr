//
//  SineScrollerEffect.swift
//  RetroSVRCore · RetroSVR
//
//  Demoscene sine scroller: rainbow text waving across raster bars.
//

import Foundation

/// Scrolling, sine-distorted rainbow text between two bouncing copper bars.
public final class SineScrollerEffect: Effect {
    /// 5×7 glyphs stored as five column bytes; bit *n* is row *n* from the top.
    private static let font: [Character: [UInt8]] = [
        "R": [0x7C, 0x12, 0x12, 0x12, 0x6C],
        "E": [0x7E, 0x4A, 0x4A, 0x4A, 0x42],
        "T": [0x02, 0x02, 0x7E, 0x02, 0x02],
        "O": [0x3C, 0x42, 0x42, 0x42, 0x3C],
        "8": [0x34, 0x4A, 0x4A, 0x4A, 0x34],
        "B": [0x7E, 0x4A, 0x4A, 0x4A, 0x34],
        "I": [0x00, 0x42, 0x7E, 0x42, 0x00],
        " ": [0x00, 0x00, 0x00, 0x00, 0x00],
        "S": [0x24, 0x4A, 0x4A, 0x4A, 0x30],
        "C": [0x3C, 0x42, 0x42, 0x42, 0x24],
        "N": [0x7E, 0x04, 0x08, 0x10, 0x7E],
        "A": [0x7C, 0x12, 0x12, 0x12, 0x7C],
        "V": [0x1E, 0x20, 0x40, 0x20, 0x1E],
        "!": [0x00, 0x00, 0x5E, 0x00, 0x00],
    ]
    private static let scrollText = "RETRO 8BIT SCREENSAVER !!! "
    private static let glyphColumns = 5
    private static let glyphRows = 7
    /// Glyph advance, including one column of spacing.
    private static let charAdvance = 6
    private static let barHeight = 3

    public let kind = EffectKind.sineScroller

    private var width = 0
    private var height = 0
    private var time = 0.0
    private let palette = RetroPalette.rainbow()
    private let dimPalette = RetroPalette.rainbow().map { PixelColor.dimmed($0, by: 6) }
    /// Glyphs for each character of the text; unknown characters leave a gap.
    private let glyphs: [[UInt8]?] = scrollText.map { font[$0] }

    public init() {}

    public func initialize(width: Int, height: Int) {
        self.width = width
        self.height = height
        time = 0
    }

    public func update(deltaTime: Double) {
        time += deltaTime * 60
    }

    public func render(into buffer: RenderBuffer) {
        buffer.clear()
        drawBackgroundBars(buffer)
        drawScrollText(buffer)
        drawBouncingBars(buffer)
    }

    /// Dim rainbow raster lines: two lit rows out of every four.
    private func drawBackgroundBars(_ buffer: RenderBuffer) {
        for y in 0..<height where y % 4 < 2 {
            let offset = Int(time * 0.5 + Double(y * 2)) % 256
            for x in 0..<width {
                buffer.setPixel(x: x, y: y, color: dimPalette[(offset + x) % 256])
            }
        }
    }

    private func drawScrollText(_ buffer: RenderBuffer) {
        let scale = max(1, height / 50)
        let advance = Self.charAdvance * scale
        let textY = height / 2 - (Self.glyphRows * scale) / 2
        let scrollOffset = Int(time * 1.5) % (glyphs.count * advance + width)

        for (i, glyph) in glyphs.enumerated() {
            guard let glyph else { continue }
            let charX = width - scrollOffset + i * advance
            guard charX + advance >= 0, charX <= width else { continue }

            for column in 0..<Self.glyphColumns {
                let drawX = charX + column * scale
                let sineOffset = sin((Double(drawX) + time * 2) * 0.05) * (Double(height) * 0.15)
                var colorIndex = Int(Double(drawX) + time) % 256
                if colorIndex < 0 { colorIndex += 256 }
                let color = palette[colorIndex]

                let bits = glyph[column]
                for row in 0..<Self.glyphRows where bits & (1 << row) != 0 {
                    let drawY = textY + row * scale + Int(sineOffset)
                    for sy in 0..<scale {
                        for sx in 0..<scale {
                            buffer.setPixel(x: drawX + sx, y: drawY + sy, color: color)
                        }
                    }
                }
            }
        }
    }

    /// Rainbow bars bobbing near the top and bottom edges, scrolling in opposite directions.
    private func drawBouncingBars(_ buffer: RenderBuffer) {
        let topY = Int(sin(time * 0.08) * 10 + 12)
        let bottomY = height - Int(sin(time * 0.08 + Double.pi) * 10 + 15)
        let shift = Int(time * 2)

        for x in 0..<width {
            let topColor = palette[(x + shift) % 256]
            let bottomColor = palette[(width - x + shift) % 256]
            for row in 0..<Self.barHeight {
                buffer.setPixel(x: x, y: topY + row, color: topColor)
                buffer.setPixel(x: x, y: bottomY + row, color: bottomColor)
            }
        }
    }

    public func reset() {
        time = 0
    }
}
