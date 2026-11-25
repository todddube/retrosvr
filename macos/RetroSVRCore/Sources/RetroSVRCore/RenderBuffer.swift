//
//  RenderBuffer.swift
//  RetroSVRCore · RetroSVR
//
//  The low-resolution pixel buffer effects draw into, and its conversion to a CGImage.
//

import CoreGraphics
import Foundation

/// Helpers for packed `0xAARRGGBB` pixels.
///
/// Stored as native little-endian `UInt32`, which CoreGraphics reads as
/// `byteOrder32Little` + `noneSkipFirst` without any per-pixel conversion.
public enum PixelColor {
    public static let black: UInt32 = 0xFF00_0000

    /// Packs 0–255 channel values (clamped) into an opaque pixel.
    @inlinable
    public static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> UInt32 {
        0xFF00_0000
            | UInt32(min(max(red, 0), 255)) << 16
            | UInt32(min(max(green, 0), 255)) << 8
            | UInt32(min(max(blue, 0), 255))
    }

    @inlinable public static func red(_ pixel: UInt32) -> Int { Int((pixel >> 16) & 0xFF) }
    @inlinable public static func green(_ pixel: UInt32) -> Int { Int((pixel >> 8) & 0xFF) }
    @inlinable public static func blue(_ pixel: UInt32) -> Int { Int(pixel & 0xFF) }

    /// Divides each channel by `divisor`, used to dim a colour.
    @inlinable
    public static func dimmed(_ pixel: UInt32, by divisor: Int) -> UInt32 {
        rgb(red(pixel) / divisor, green(pixel) / divisor, blue(pixel) / divisor)
    }
}

/// A chunky-pixel frame buffer. One buffer pixel becomes a `pixelScale`-sized block on screen;
/// the view does that scaling on the GPU with nearest-neighbour filtering.
public final class RenderBuffer {
    public let width: Int
    public let height: Int
    /// Row-major pixels, top row first.
    public internal(set) var pixels: [UInt32]

    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        pixels = Array(repeating: PixelColor.black, count: self.width * self.height)
    }

    /// Sets one pixel, ignoring coordinates outside the buffer.
    @inline(__always)
    public func setPixel(x: Int, y: Int, color: UInt32) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        pixels[y * width + x] = color
    }

    /// Returns one pixel, or black outside the buffer.
    @inline(__always)
    public func pixel(x: Int, y: Int) -> UInt32 {
        guard x >= 0, x < width, y >= 0, y < height else { return PixelColor.black }
        return pixels[y * width + x]
    }

    /// Fills the whole buffer with one colour.
    public func clear(to color: UInt32 = PixelColor.black) {
        pixels.withUnsafeMutableBufferPointer { $0.update(repeating: color) }
    }

    /// Draws a horizontal line, clipped to the buffer.
    public func drawHorizontalLine(fromX x1: Int, toX x2: Int, y: Int, color: UInt32) {
        guard y >= 0, y < height else { return }
        let start = max(0, min(x1, x2))
        let end = min(width - 1, max(x1, x2))
        guard start <= end else { return }
        let row = y * width
        for x in start...end { pixels[row + x] = color }
    }

    /// Draws a vertical line, clipped to the buffer.
    public func drawVerticalLine(x: Int, fromY y1: Int, toY y2: Int, color: UInt32) {
        guard x >= 0, x < width else { return }
        let start = max(0, min(y1, y2))
        let end = min(height - 1, max(y1, y2))
        guard start <= end else { return }
        for y in start...end { pixels[y * width + x] = color }
    }

    /// Crossfades `other` over this buffer: `alpha` 0 keeps this buffer, 1 shows `other`.
    public func blend(_ other: RenderBuffer, alpha: Double) {
        precondition(other.width == width && other.height == height, "blend needs equal sizes")
        let a = Int(min(max(alpha, 0), 1) * 255)
        let inverse = 255 - a
        pixels.withUnsafeMutableBufferPointer { dest in
            other.pixels.withUnsafeBufferPointer { src in
                for i in 0..<dest.count {
                    let d = dest[i]
                    let s = src[i]
                    dest[i] = PixelColor.rgb(
                        (PixelColor.red(d) * inverse + PixelColor.red(s) * a) / 255,
                        (PixelColor.green(d) * inverse + PixelColor.green(s) * a) / 255,
                        (PixelColor.blue(d) * inverse + PixelColor.blue(s) * a) / 255
                    )
                }
            }
        }
    }

    /// Snapshots the buffer as an unscaled, opaque CGImage.
    public func makeImage() -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let data = pixels.withUnsafeBytes { Data($0) } as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: Self.bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// The CoreGraphics layout matching ``pixels``; use it to draw into a buffer-shaped context.
    public static let bitmapInfo = CGBitmapInfo(
        rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )
}
