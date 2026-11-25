//
//  DesktopImageSource.swift
//  RetroSVR · RetroSVR
//
//  Supplies the desktop wallpaper, shrunk to buffer size, for the Dissolver to crumble.
//

import AppKit
import ImageIO
import RetroSVRCore
import os

/// Loads a screen's wallpaper as chunky pixels.
///
/// Windows captured the live screen, but that captured the saver's own black window. On
/// macOS a real screen capture needs Screen Recording permission, which a screen saver
/// can't request. The wallpaper is the closest honest stand-in. When it can't be read (a
/// dynamic or video wallpaper, or the sandbox refuses), the Dissolver uses its built-in pattern.
@MainActor
final class DesktopImageSource {
    private struct CacheKey: Equatable {
        let url: URL
        let width: Int
        let height: Int
    }

    private static let logger = Logger(subsystem: SettingsStore.moduleName, category: "desktop")

    private var cacheKey: CacheKey?
    private var cachedPixels: [UInt32]?

    /// Returns `screen`'s wallpaper as `width × height` row-major pixels, or `nil` if it can't
    /// be read. The last result, including a failure, is cached per wallpaper URL and size.
    func pixels(for screen: NSScreen, width: Int, height: Int) -> [UInt32]? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        let key = CacheKey(url: url, width: width, height: height)
        if key == cacheKey { return cachedPixels }

        let pixels = Self.loadPixels(from: url, width: width, height: height)
        if pixels == nil {
            Self.logger.debug("Wallpaper unavailable; using the built-in pattern")
        }
        cacheKey = key
        cachedPixels = pixels
        return pixels
    }

    /// Decodes `url` and draws it aspect-filled into a `width × height` buffer.
    private static func loadPixels(from url: URL, width: Int, height: Int) -> [UInt32]? {
        guard width > 0, height > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // A thumbnail decode avoids inflating a full 6K wallpaper just to shrink it.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height) * 4,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let fill = max(CGFloat(width) / imageWidth, CGFloat(height) / imageHeight)
        let drawSize = CGSize(width: imageWidth * fill, height: imageHeight * fill)
        let drawRect = CGRect(
            x: (CGFloat(width) - drawSize.width) / 2,
            y: (CGFloat(height) - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        var pixels = [UInt32](repeating: PixelColor.black, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: RenderBuffer.bitmapInfo.rawValue
            ) else { return false }
            // Nearest-neighbour, like the Windows capture, for hard-edged chunky pixels.
            context.interpolationQuality = .none
            context.draw(image, in: drawRect)
            return true
        }
        return drawn ? pixels : nil
    }
}
