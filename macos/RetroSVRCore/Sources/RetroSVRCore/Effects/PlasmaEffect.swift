//
//  PlasmaEffect.swift
//  RetroSVRCore · RetroSVR
//
//  Classic demoscene plasma: five interfering sine waves mapped through a cycling palette.
//

import Foundation

/// Flowing colour made by summing table-driven sine waves per pixel.
public final class PlasmaEffect: Effect {
    private static let tableSize = 1024
    /// Converts radians to a sine-table index (`tableSize / 2π`).
    private static let radiansToIndex = Double(tableSize) / (2 * Double.pi)

    public let kind = EffectKind.plasma

    private var width = 0
    private var height = 0
    private var time = 0.0
    private let palette = RetroPalette.plasma()
    private let sineTable: [Double] = (0..<tableSize).map {
        sin(Double($0) * 2 * Double.pi / Double(tableSize))
    }
    // Per-pixel distance and angle from the centre never change for a given size, so they're
    // computed once here instead of a sqrt and atan2 per pixel per frame.
    private var distances: [Double] = []
    private var angles: [Double] = []

    public init() {}

    public func initialize(width: Int, height: Int) {
        self.width = width
        self.height = height
        time = 0
        distances = []
        angles = []
        distances.reserveCapacity(width * height)
        angles.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let cx = Double(x) - Double(width) / 2
                let cy = Double(y) - Double(height) / 2
                distances.append((cx * cx + cy * cy).squareRoot())
                angles.append(atan2(cy, cx))
            }
        }
    }

    public func update(deltaTime: Double) {
        time += deltaTime * 50
    }

    public func render(into buffer: RenderBuffer) {
        guard buffer.width == width, buffer.height == height else { return }
        // The wave phases step in whole time units, which gives the original's slightly
        // stepped motion.
        let t = Double(Int(time))
        sineTable.withUnsafeBufferPointer { table in
            func wave(_ x: Double) -> Double {
                table[Int(x * Self.radiansToIndex) & (Self.tableSize - 1)]
            }
            buffer.pixels.withUnsafeMutableBufferPointer { pixels in
                for y in 0..<height {
                    let fy = Double(y)
                    let horizontal = wave((fy + t * 0.5) * 0.06)
                    for x in 0..<width {
                        let i = y * width + x
                        let fx = Double(x)
                        var value = horizontal
                        value += wave((fx + t) * 0.08)
                        value += wave((distances[i] - t * 0.8) * 0.1)
                        value += wave((fx * 0.05 + fy * 0.05 + t * 0.3) * 0.9)
                        value += wave((angles[i] * 4 + t * 0.1) * 0.5)

                        var index = Int((value + 5) * 25.5) % 256
                        if index < 0 { index += 256 }
                        pixels[i] = palette[index]
                    }
                }
            }
        }
    }

    public func reset() {
        time = 0
    }
}
