// swift-tools-version: 6.0
// RetroSVRCore: the platform-neutral engine (effects, palettes, settings, sound synthesis)
// behind the RetroSVR macOS screen saver. No AppKit, so it builds and tests from the terminal.

import PackageDescription

let package = Package(
    name: "RetroSVRCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RetroSVRCore", targets: ["RetroSVRCore"]),
    ],
    targets: [
        .target(name: "RetroSVRCore"),
        .testTarget(name: "RetroSVRCoreTests", dependencies: ["RetroSVRCore"]),
    ]
)
