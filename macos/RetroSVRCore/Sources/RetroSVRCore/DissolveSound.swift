//
//  DissolveSound.swift
//  RetroSVRCore · RetroSVR
//
//  Synthesizes the Dissolver's crackling sound as an in-memory WAV file.
//

import Foundation

/// The Dissolver's crackle: soft noise plus random pops that swell to a peak and fade away.
public enum DissolveSound {
    public static let sampleRate = 22_050
    /// Roughly how long the particles take to fall.
    public static let duration = 28.0

    /// Returns an 8-bit mono PCM WAV file. The fixed seed makes every run sound the same.
    public static func makeWAV() -> Data {
        let sampleCount = Int(Double(sampleRate) * duration)
        var data = Data()
        data.reserveCapacity(44 + sampleCount)

        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append32(36 + sampleCount)
        append("WAVE")
        append("fmt ")
        append32(16)          // fmt chunk size
        append16(1)           // PCM
        append16(1)           // mono
        append32(sampleRate)
        append32(sampleRate)  // byte rate: rate × channels × 1 byte
        append16(1)           // block align
        append16(8)           // bits per sample
        append("data")
        append32(sampleCount)

        var random = FastRandom(seed: 42)
        var samples = [UInt8](repeating: 128, count: sampleCount)
        for i in 0..<sampleCount {
            let progress = Double(i) / Double(sampleRate) / duration
            let envelope = Self.envelope(at: progress)

            var sample = (random.nextDouble() - 0.5) * (0.05 + envelope * 0.15)
            if random.nextDouble() < 0.01 + envelope * 0.04 {
                sample += (random.nextDouble() - 0.5) * (0.2 + envelope * 0.3)
            }
            if random.nextDouble() < 0.002 + envelope * 0.008 {
                sample += (random.nextDouble() - 0.5) * (0.3 + envelope * 0.4)
            }
            sample *= envelope * 0.45

            samples[i] = UInt8(Int((sample + 0.5) * 255).clamped(to: 0...255))
        }
        data.append(contentsOf: samples)
        return data
    }

    /// Loudness over the sound's life (`progress` 0–1): a quiet start, a peak at 65%, then
    /// a linear fade.
    static func envelope(at progress: Double) -> Double {
        switch progress {
        case ..<0.15: progress / 0.15 * 0.2
        case ..<0.65: 0.2 + (progress - 0.15) / 0.5 * 0.8
        default: max(0, 1 - (progress - 0.65) / 0.35)
        }
    }
}
