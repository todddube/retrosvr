//
//  RetroPalette.swift
//  RetroSVRCore · RetroSVR
//
//  Period colour palettes and the 256-entry gradients the effects index into.
//

import Foundation

/// Classic 8-bit palettes and effect gradients, as packed ``PixelColor`` values.
public enum RetroPalette {
    /// The 16-colour IBM CGA palette.
    public static let cga: [UInt32] = [
        PixelColor.rgb(0, 0, 0), PixelColor.rgb(0, 0, 170),
        PixelColor.rgb(0, 170, 0), PixelColor.rgb(0, 170, 170),
        PixelColor.rgb(170, 0, 0), PixelColor.rgb(170, 0, 170),
        PixelColor.rgb(170, 85, 0), PixelColor.rgb(170, 170, 170),
        PixelColor.rgb(85, 85, 85), PixelColor.rgb(85, 85, 255),
        PixelColor.rgb(85, 255, 85), PixelColor.rgb(85, 255, 255),
        PixelColor.rgb(255, 85, 85), PixelColor.rgb(255, 85, 255),
        PixelColor.rgb(255, 255, 85), PixelColor.rgb(255, 255, 255),
    ]

    /// A Commodore 64-inspired 16-colour palette.
    public static let c64: [UInt32] = [
        PixelColor.rgb(0, 0, 0), PixelColor.rgb(255, 255, 255),
        PixelColor.rgb(136, 57, 50), PixelColor.rgb(103, 182, 189),
        PixelColor.rgb(139, 63, 150), PixelColor.rgb(85, 160, 73),
        PixelColor.rgb(64, 49, 141), PixelColor.rgb(191, 206, 114),
        PixelColor.rgb(139, 84, 41), PixelColor.rgb(87, 66, 0),
        PixelColor.rgb(184, 105, 98), PixelColor.rgb(80, 80, 80),
        PixelColor.rgb(120, 120, 120), PixelColor.rgb(148, 224, 137),
        PixelColor.rgb(120, 105, 196), PixelColor.rgb(159, 159, 159),
    ]

    /// Black → red → orange → yellow → white.
    public static func fire() -> [UInt32] {
        (0..<256).map { i in
            switch i {
            case 0..<64: PixelColor.rgb(i * 4, 0, 0)
            case 64..<128: PixelColor.rgb(255, (i - 64) * 4, 0)
            case 128..<192: PixelColor.rgb(255, 255, (i - 128) * 4)
            default: PixelColor.rgb(255, 255, 255)
            }
        }
    }

    /// Three out-of-phase sine waves, for the plasma.
    public static func plasma() -> [UInt32] {
        (0..<256).map { i in
            let x = Double(i)
            return PixelColor.rgb(
                Int(128 + 127 * sin(Double.pi * x / 32)),
                Int(128 + 127 * sin(Double.pi * x / 64 + 2)),
                Int(128 + 127 * sin(Double.pi * x / 128 + 4))
            )
        }
    }

    /// Dark to bright phosphor green.
    public static func matrix() -> [UInt32] {
        (0..<256).map { PixelColor.rgb($0 / 4, $0, $0 / 3) }
    }

    /// Dim to bright white with a slight blue tint.
    public static func starfield() -> [UInt32] {
        (0..<256).map { i in
            PixelColor.rgb(min(255, i + i / 8), min(255, i + i / 8), min(255, i + i / 4))
        }
    }

    /// A full-saturation hue wheel.
    public static func rainbow() -> [UInt32] {
        (0..<256).map { hsvToRGB(hue: Double($0) / 256, saturation: 1, value: 1) }
    }

    static func hsvToRGB(hue h: Double, saturation s: Double, value v: Double) -> UInt32 {
        let sector = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let (r, g, b): (Double, Double, Double) = switch sector {
        case 0: (v, t, p)
        case 1: (q, v, p)
        case 2: (p, v, t)
        case 3: (p, q, v)
        case 4: (t, p, v)
        default: (v, p, q)
        }
        return PixelColor.rgb(Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
