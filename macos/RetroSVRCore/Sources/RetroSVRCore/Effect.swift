//
//  Effect.swift
//  RetroSVRCore · RetroSVR
//
//  The contract every demoscene effect implements, and the catalogue of effects.
//

/// A full-screen animated effect drawn into a low-resolution ``RenderBuffer``.
///
/// ``EffectManager`` drives each effect: ``initialize(width:height:)`` once per buffer size,
/// then ``update(deltaTime:)`` and ``render(into:)`` every frame. Sizes are in chunky
/// (already scaled-down) pixels, the same size as the buffer passed to ``render(into:)``.
public protocol Effect: AnyObject {
    /// The kind this instance implements.
    var kind: EffectKind { get }

    /// Prepares the effect for a buffer of the given size.
    func initialize(width: Int, height: Int)

    /// Advances the animation by `deltaTime` seconds.
    func update(deltaTime: Double)

    /// Draws the current frame. Effects that don't cover every pixel clear the buffer first.
    func render(into buffer: RenderBuffer)

    /// Restarts the animation from its initial state, keeping the current size.
    func reset()

    /// Releases anything that outlives a frame, such as a playing sound.
    func stop()
}

extension Effect {
    public func stop() {}
}

/// The effects RetroSVR ships, in cycling order.
public enum EffectKind: String, CaseIterable, Sendable {
    case starfield
    case plasma
    case fire
    case matrixRain
    case sineScroller
    case dissolver

    /// The name shown in the settings sheet.
    public var displayName: String {
        switch self {
        case .starfield: "Starfield"
        case .plasma: "Plasma"
        case .fire: "Fire"
        case .matrixRain: "Matrix Rain"
        case .sineScroller: "Sine Scroller"
        case .dissolver: "Dissolver"
        }
    }
}

/// Which effect the saver shows: one fixed effect, or all of them in turn.
public enum EffectSelection: Hashable, Sendable {
    case cycleAll
    case single(EffectKind)
}
