//
//  EffectManagerTests.swift
//  RetroSVRCoreTests · RetroSVR
//
//  Cycling, crossfade and sizing behaviour of the effect manager.
//

import Testing

@testable import RetroSVRCore

/// A stand-in effect that records how the manager drives it.
private final class ProbeEffect: Effect {
    let kind: EffectKind
    let color: UInt32
    var initializedSize: (width: Int, height: Int)?
    var updateCount = 0
    var resetCount = 0
    var stopCount = 0

    init(kind: EffectKind, color: UInt32) {
        self.kind = kind
        self.color = color
    }

    func initialize(width: Int, height: Int) { initializedSize = (width, height) }
    func update(deltaTime: Double) { updateCount += 1 }
    func render(into buffer: RenderBuffer) { buffer.clear(to: color) }
    func reset() { resetCount += 1 }
    func stop() { stopCount += 1 }
}

private func makeProbes() -> [ProbeEffect] {
    [
        ProbeEffect(kind: .starfield, color: PixelColor.rgb(0, 0, 0)),
        ProbeEffect(kind: .plasma, color: PixelColor.rgb(254, 254, 254)),
        ProbeEffect(kind: .fire, color: PixelColor.rgb(10, 20, 30)),
    ]
}

@Test func effectsAreInitializedAtBufferSize() {
    let probes = makeProbes()
    let manager = EffectManager(effects: probes)
    manager.initialize(width: 120, height: 80)
    for probe in probes {
        #expect(probe.initializedSize?.width == 120)
        #expect(probe.initializedSize?.height == 80)
    }
}

@Test func cyclesAfterDurationWithCrossfade() {
    let probes = makeProbes()
    let manager = EffectManager(effects: probes)
    manager.effectDuration = 1
    manager.initialize(width: 4, height: 4)

    manager.update(deltaTime: 0.6)
    #expect(manager.currentEffect?.kind == .starfield)
    #expect(!manager.isTransitioning)

    manager.update(deltaTime: 0.5)
    #expect(manager.isTransitioning)
    #expect(probes[1].resetCount == 1)

    // Halfway through the 0.5 s crossfade: the black and near-white probes mix to grey.
    manager.update(deltaTime: 0.25)
    let buffer = RenderBuffer(width: 4, height: 4)
    manager.render(into: buffer)
    #expect((120...135).contains(PixelColor.red(buffer.pixel(x: 0, y: 0))))

    manager.update(deltaTime: 0.3)
    #expect(!manager.isTransitioning)
    #expect(manager.currentEffect?.kind == .plasma)
    #expect(probes[0].stopCount == 1, "the outgoing effect is stopped so its sound can't linger")
}

@Test func cutsInstantlyWithoutSmoothTransitions() {
    let probes = makeProbes()
    let manager = EffectManager(effects: probes)
    manager.effectDuration = 1
    manager.smoothTransitions = false
    manager.initialize(width: 4, height: 4)

    manager.update(deltaTime: 1.1)
    #expect(manager.currentEffect?.kind == .plasma)
    #expect(!manager.isTransitioning)
}

@Test func wrapsAroundToFirstEffect() {
    let manager = EffectManager(effects: makeProbes())
    manager.effectDuration = 1
    manager.smoothTransitions = false
    manager.initialize(width: 4, height: 4)
    for _ in 0..<3 { manager.update(deltaTime: 1.1) }
    #expect(manager.currentEffect?.kind == .starfield)
}

@Test func singleSelectionNeverCycles() {
    let manager = EffectManager(effects: makeProbes())
    manager.apply(SaverSettings(selection: .single(.fire), effectDuration: 5))
    manager.initialize(width: 4, height: 4)
    #expect(manager.currentEffect?.kind == .fire)
    for _ in 0..<20 { manager.update(deltaTime: 0.1) }
    #expect(manager.currentEffect?.kind == .fire)
}

@Test func defaultEffectsCoverEveryKindInOrder() {
    let kinds = EffectManager.makeEffects().map(\.kind)
    #expect(kinds == EffectKind.allCases)
}

@Test func applyingANewSelectionSwitchesImmediately() {
    let probes = makeProbes()
    let manager = EffectManager(effects: probes)
    manager.initialize(width: 4, height: 4)
    #expect(manager.currentEffect?.kind == .starfield)

    manager.apply(SaverSettings(selection: .single(.fire)))
    #expect(manager.currentEffect?.kind == .fire)
    #expect(probes[0].stopCount == 1)
    #expect(probes[2].resetCount == 1)

    manager.apply(SaverSettings(selection: .single(.fire), effectDuration: 60))
    #expect(probes[2].resetCount == 1, "an unchanged selection doesn't restart the effect")
}

@Test func stopReachesEveryEffect() {
    let probes = makeProbes()
    EffectManager(effects: probes).stop()
    #expect(probes.allSatisfy { $0.stopCount == 1 })
}
