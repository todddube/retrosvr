//
//  EffectManager.swift
//  RetroSVRCore · RetroSVR
//
//  Runs the effect lifecycle: choosing, cycling and crossfading between effects.
//

/// Owns one instance of each effect and decides which one draws each frame.
///
/// In ``EffectSelection/cycleAll`` mode it advances to the next effect every
/// ``effectDuration`` seconds, either cutting or crossfading over ``transitionDuration``.
public final class EffectManager {
    /// Length of the crossfade between effects, in seconds.
    public static let transitionDuration = 0.5

    public let effects: [any Effect]
    public private(set) var selection: EffectSelection = .cycleAll
    public var smoothTransitions = true
    /// Seconds each effect shows before cycling.
    public var effectDuration: Double = 30

    private var currentIndex = 0
    private var nextIndex = 0
    private var effectTimer = 0.0
    private var transitionProgress = 0.0
    public private(set) var isTransitioning = false
    private var transitionBuffer: RenderBuffer?

    /// Creates a manager over `effects`, cycled in array order.
    public init(effects: [any Effect] = EffectManager.makeEffects()) {
        self.effects = effects
    }

    /// One instance of every ``EffectKind``, in cycling order.
    public static func makeEffects(dissolverHooks: DissolverEffect.Hooks = .init()) -> [any Effect] {
        EffectKind.allCases.map { kind -> any Effect in
            switch kind {
            case .starfield: StarfieldEffect()
            case .plasma: PlasmaEffect()
            case .fire: FireEffect()
            case .matrixRain: MatrixRainEffect()
            case .sineScroller: SineScrollerEffect()
            case .dissolver: DissolverEffect(hooks: dissolverHooks)
            }
        }
    }

    /// The effect currently on screen (the outgoing one during a crossfade).
    public var currentEffect: (any Effect)? {
        effects.indices.contains(currentIndex) ? effects[currentIndex] : nil
    }

    /// Copies the cycling options from `settings`; they take effect from the next frame.
    ///
    /// A changed selection switches to its starting effect immediately.
    public func apply(_ settings: SaverSettings) {
        smoothTransitions = settings.smoothTransitions
        effectDuration = Double(settings.effectDuration)
        guard settings.selection != selection else { return }
        selection = settings.selection
        currentEffect?.stop()
        if isTransitioning { effects[nextIndex].stop() }
        selectStartingEffect()
        currentEffect?.reset()
    }

    /// Sizes every effect for a `width` × `height` buffer and starts the selected effect.
    ///
    /// Pass the *buffer* size, not the screen size. The Windows version passed the window
    /// size here, so effects simulated 16× too many pixels and only their top-left
    /// quarter was visible.
    public func initialize(width: Int, height: Int) {
        for effect in effects {
            effect.initialize(width: width, height: height)
        }
        transitionBuffer = RenderBuffer(width: width, height: height)

        selectStartingEffect()
    }

    private func selectStartingEffect() {
        switch selection {
        case .cycleAll:
            currentIndex = 0
        case .single(let kind):
            currentIndex = effects.firstIndex { $0.kind == kind } ?? 0
        }
        effectTimer = 0
        isTransitioning = false
    }

    /// Advances the current effect (and the incoming one during a crossfade) by `deltaTime`
    /// seconds, and starts or finishes a transition when cycling.
    public func update(deltaTime: Double) {
        guard let current = currentEffect else { return }
        current.update(deltaTime: deltaTime)

        guard selection == .cycleAll else { return }

        if isTransitioning {
            transitionProgress += deltaTime / Self.transitionDuration
            if transitionProgress >= 1 {
                finishTransition()
            } else {
                effects[nextIndex].update(deltaTime: deltaTime)
            }
        } else {
            effectTimer += deltaTime
            if effectTimer >= effectDuration {
                startTransition()
            }
        }
    }

    /// Draws the current effect into `buffer`, blending in the incoming one during a crossfade.
    public func render(into buffer: RenderBuffer) {
        guard let current = currentEffect else { return }
        current.render(into: buffer)

        if isTransitioning, let transitionBuffer,
           transitionBuffer.width == buffer.width, transitionBuffer.height == buffer.height {
            effects[nextIndex].render(into: transitionBuffer)
            buffer.blend(transitionBuffer, alpha: transitionProgress)
        }
    }

    /// Stops every effect's side effects (such as sound), for when the saver stops.
    public func stop() {
        for effect in effects {
            effect.stop()
        }
    }

    private func startTransition() {
        nextIndex = (currentIndex + 1) % effects.count
        effects[nextIndex].reset()
        if smoothTransitions {
            isTransitioning = true
            transitionProgress = 0
        } else {
            finishTransition()
        }
    }

    private func finishTransition() {
        // Without this the Dissolver's sound kept playing into the next effect.
        effects[currentIndex].stop()
        currentIndex = nextIndex
        isTransitioning = false
        effectTimer = 0
    }
}
