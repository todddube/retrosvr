//
//  DissolveSoundPlayer.swift
//  RetroSVR · RetroSVR
//
//  Plays the synthesized dissolve crackle, once, however many screens are dissolving.
//

import AVFoundation
import RetroSVRCore
import os

/// Shared player for the Dissolver's sound.
///
/// Every display runs its own Dissolver, and they finish their patterns at different times.
/// Counting active dissolves keeps it to one voice that only stops when the last screen ends.
@MainActor
final class DissolveSoundPlayer {
    static let shared = DissolveSoundPlayer()

    private static let logger = Logger(subsystem: SettingsStore.moduleName, category: "sound")

    private lazy var player: AVAudioPlayer? = {
        do {
            let player = try AVAudioPlayer(data: DissolveSound.makeWAV())
            player.prepareToPlay()
            return player
        } catch {
            // Sound is decoration; the effect runs silently without it.
            Self.logger.error("Couldn't create dissolve sound player: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    private init() {}

    /// Number of screens currently dissolving.
    private var activeDissolves = 0

    /// Builds the sound now, so its synthesis doesn't stall the first Dissolver frame.
    func prepare() {
        _ = player
    }

    /// Records that a screen started dissolving; the crackle starts with the first one.
    func dissolveBegan() {
        activeDissolves += 1
        guard activeDissolves == 1, let player else { return }
        player.currentTime = 0
        player.play()
    }

    /// Records that a screen stopped dissolving; the crackle stops with the last one.
    func dissolveEnded() {
        activeDissolves = max(0, activeDissolves - 1)
        if activeDissolves == 0 {
            player?.stop()
        }
    }
}
