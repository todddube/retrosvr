//
//  SnapshotTests.swift
//  RetroSVRCoreTests · RetroSVR
//
//  Opt-in: writes a PNG of every effect, for eyeballing changes without installing the saver.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import RetroSVRCore

/// Set `RETROSVR_SNAPSHOT_DIR` to a folder to enable, e.g.
/// `RETROSVR_SNAPSHOT_DIR=/tmp/shots swift test --filter Snapshot`.
private let snapshotDirectory = ProcessInfo.processInfo.environment["RETROSVR_SNAPSHOT_DIR"]

@Test(.enabled(if: snapshotDirectory != nil), arguments: EffectKind.allCases)
func snapshotEffect(kind: EffectKind) throws {
    let directory = URL(fileURLWithPath: try #require(snapshotDirectory), isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    // A 1512×982-point MacBook screen at the default 4× pixel scale.
    let width = 378
    let height = 246
    let effect = try #require(EffectManager.makeEffects().first { $0.kind == kind })
    effect.initialize(width: width, height: height)
    let seconds = kind == .dissolver ? 8.0 : 4.0
    for _ in 0..<Int(seconds * 30) {
        effect.update(deltaTime: 1.0 / 30)
    }
    let buffer = RenderBuffer(width: width, height: height)
    effect.render(into: buffer)

    let url = directory.appendingPathComponent("\(kind.rawValue).png")
    let image = try #require(buffer.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}
