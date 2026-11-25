//
//  FastRandom.swift
//  RetroSVRCore · RetroSVR
//
//  A small seedable random generator for the effects' per-pixel randomness.
//

/// A SplitMix64 generator: cheap enough to call per pixel every frame, and seedable so tests
/// and the synthesized dissolve sound are reproducible.
public struct FastRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// Creates a generator with a fixed seed.
    public init(seed: UInt64) {
        state = seed
    }

    /// Creates a generator seeded from the system's random source.
    public init() {
        var system = SystemRandomNumberGenerator()
        state = system.next()
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform value in `0..<1`.
    public mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// A uniform integer in `range`, or its lower bound when the range is empty.
    ///
    /// Mirrors .NET's `Random.Next(min, max)`, which returns `min` for an empty range instead
    /// of trapping; effects rely on that when a buffer dimension is tiny.
    public mutating func nextInt(in range: Range<Int>) -> Int {
        guard range.count > 1 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(range.count))
    }
}
