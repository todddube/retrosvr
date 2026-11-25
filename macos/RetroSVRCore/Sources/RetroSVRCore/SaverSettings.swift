//
//  SaverSettings.swift
//  RetroSVRCore · RetroSVR
//
//  User-configurable options and their persistence in a UserDefaults domain.
//

import Foundation

/// The saver's options. The ranges and defaults match the Windows version's settings dialog.
public struct SaverSettings: Equatable, Sendable {
    public static let effectDurationRange = 5...120
    public static let pixelScaleRange = 1...8
    public static let frameRateRange = 15...60

    public var selection: EffectSelection
    /// Seconds each effect shows before cycling (only used with ``EffectSelection/cycleAll``).
    public var effectDuration: Int
    /// Screen points per chunky pixel.
    public var pixelScale: Int
    /// Frames per second the screen saver host animates at.
    public var frameRate: Int
    /// Crossfade between effects instead of cutting.
    public var smoothTransitions: Bool
    /// Play the Dissolver's crackle. New on macOS; Windows always played it.
    public var soundEnabled: Bool

    public init(
        selection: EffectSelection = .cycleAll,
        effectDuration: Int = 30,
        pixelScale: Int = 4,
        frameRate: Int = 30,
        smoothTransitions: Bool = true,
        soundEnabled: Bool = true
    ) {
        self.selection = selection
        self.effectDuration = effectDuration.clamped(to: Self.effectDurationRange)
        self.pixelScale = pixelScale.clamped(to: Self.pixelScaleRange)
        self.frameRate = frameRate.clamped(to: Self.frameRateRange)
        self.smoothTransitions = smoothTransitions
        self.soundEnabled = soundEnabled
    }

    // MARK: - Persistence

    private enum Key {
        static let effect = "effect"
        static let effectDuration = "effectDuration"
        static let pixelScale = "pixelScale"
        static let frameRate = "frameRate"
        static let smoothTransitions = "smoothTransitions"
        static let soundEnabled = "soundEnabled"
    }

    private static let cycleAllValue = "all"

    /// Reads settings, falling back to defaults for missing or invalid values.
    public static func load(from defaults: UserDefaults) -> SaverSettings {
        let fallback = SaverSettings()
        let selection: EffectSelection =
            switch defaults.string(forKey: Key.effect).flatMap(EffectKind.init(rawValue:)) {
            case let kind?: .single(kind)
            case nil: .cycleAll
            }
        return SaverSettings(
            selection: selection,
            effectDuration: defaults.object(forKey: Key.effectDuration) as? Int ?? fallback.effectDuration,
            pixelScale: defaults.object(forKey: Key.pixelScale) as? Int ?? fallback.pixelScale,
            frameRate: defaults.object(forKey: Key.frameRate) as? Int ?? fallback.frameRate,
            smoothTransitions: defaults.object(forKey: Key.smoothTransitions) as? Bool ?? fallback.smoothTransitions,
            soundEnabled: defaults.object(forKey: Key.soundEnabled) as? Bool ?? fallback.soundEnabled
        )
    }

    /// Writes all settings and flushes them, which `ScreenSaverDefaults` requires.
    public func save(to defaults: UserDefaults) {
        let effect = switch selection {
        case .cycleAll: Self.cycleAllValue
        case .single(let kind): kind.rawValue
        }
        defaults.set(effect, forKey: Key.effect)
        defaults.set(effectDuration, forKey: Key.effectDuration)
        defaults.set(pixelScale, forKey: Key.pixelScale)
        defaults.set(frameRate, forKey: Key.frameRate)
        defaults.set(smoothTransitions, forKey: Key.smoothTransitions)
        defaults.set(soundEnabled, forKey: Key.soundEnabled)
        defaults.synchronize()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
