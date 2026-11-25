//
//  SaverSettingsTests.swift
//  RetroSVRCoreTests · RetroSVR
//
//  Defaults, clamping and UserDefaults round-tripping of the saver settings.
//

import Foundation
import Testing

@testable import RetroSVRCore

/// A throwaway defaults domain, removed after use.
private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let suite = "RetroSVRCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    try body(defaults)
}

@Test func defaultsMatchTheWindowsVersion() {
    let settings = SaverSettings()
    #expect(settings.selection == .cycleAll)
    #expect(settings.effectDuration == 30)
    #expect(settings.pixelScale == 4)
    #expect(settings.frameRate == 30)
    #expect(settings.smoothTransitions)
}

@Test func valuesAreClampedToTheirRanges() {
    let settings = SaverSettings(effectDuration: 1, pixelScale: 99, frameRate: 0)
    #expect(settings.effectDuration == 5)
    #expect(settings.pixelScale == 8)
    #expect(settings.frameRate == 15)
}

@Test func roundTripsThroughUserDefaults() throws {
    try withScratchDefaults { defaults in
        let saved = SaverSettings(
            selection: .single(.matrixRain), effectDuration: 45, pixelScale: 6,
            frameRate: 60, smoothTransitions: false, soundEnabled: false
        )
        saved.save(to: defaults)
        #expect(SaverSettings.load(from: defaults) == saved)
    }
}

@Test func emptyOrCorruptDefaultsFallBack() throws {
    try withScratchDefaults { defaults in
        #expect(SaverSettings.load(from: defaults) == SaverSettings())

        defaults.set("not-an-effect", forKey: "effect")
        defaults.set("thirty", forKey: "effectDuration")
        defaults.set(500, forKey: "frameRate")
        let loaded = SaverSettings.load(from: defaults)
        #expect(loaded.selection == .cycleAll)
        #expect(loaded.effectDuration == 30)
        #expect(loaded.frameRate == 60)
    }
}
