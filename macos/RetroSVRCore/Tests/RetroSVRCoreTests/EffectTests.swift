//
//  EffectTests.swift
//  RetroSVRCoreTests · RetroSVR
//
//  Smoke and behaviour tests for each effect, the buffer and the palettes.
//

import Foundation
import Testing

@testable import RetroSVRCore

/// Runs `effect` for `seconds` at 30 fps and returns the final frame.
private func run(_ effect: any Effect, width: Int = 96, height: Int = 64, seconds: Double) -> RenderBuffer {
    let buffer = RenderBuffer(width: width, height: height)
    effect.initialize(width: width, height: height)
    for _ in 0..<Int(seconds * 30) {
        effect.update(deltaTime: 1.0 / 30)
    }
    effect.render(into: buffer)
    return buffer
}

private func litPixelCount(_ buffer: RenderBuffer) -> Int {
    buffer.pixels.filter { $0 & 0x00FF_FFFF != 0 }.count
}

@Test(arguments: EffectKind.allCases)
func everyEffectDrawsSomething(kind: EffectKind) throws {
    let effect = try #require(EffectManager.makeEffects().first { $0.kind == kind })
    let buffer = run(effect, seconds: 3)
    #expect(litPixelCount(buffer) > 0, "\(kind) rendered an all-black frame")
}

@Test(arguments: EffectKind.allCases)
func everyEffectSurvivesTinyBuffers(kind: EffectKind) throws {
    let effect = try #require(EffectManager.makeEffects().first { $0.kind == kind })
    for size in [(1, 1), (2, 1), (1, 3), (3, 2)] {
        _ = run(effect, width: size.0, height: size.1, seconds: 0.5)
        effect.reset()
        effect.update(deltaTime: 0.1)
    }
}

@Test func fireFillsTheBottomOfTheBuffer() {
    let buffer = run(FireEffect(random: FastRandom(seed: 1)), seconds: 2)
    let bottomRow = buffer.pixels[(buffer.height - 1) * buffer.width..<buffer.height * buffer.width]
    #expect(bottomRow.allSatisfy { PixelColor.red($0) > 0 })
}

@Test func fireStepsAtAFixedRateRegardlessOfFrameRate() {
    let slow = FireEffect(random: FastRandom(seed: 1))
    let fast = FireEffect(random: FastRandom(seed: 1))
    slow.initialize(width: 8, height: 8)
    fast.initialize(width: 8, height: 8)
    for _ in 0..<15 { slow.update(deltaTime: 1.0 / 15) }
    for _ in 0..<60 { fast.update(deltaTime: 1.0 / 60) }
    #expect(abs(slow.stepCount - fast.stepCount) <= 1)
    #expect((29...30).contains(fast.stepCount))
}

@Test func starfieldIsCentredInTheBuffer() {
    // Regression: Windows sized effects to the window, putting the centre off-buffer.
    let buffer = run(StarfieldEffect(random: FastRandom(seed: 3)), width: 200, height: 120, seconds: 2)
    let quadrants = [(0, 0), (100, 0), (0, 60), (100, 60)].map { origin in
        (0..<60).reduce(0) { count, y in
            count + (0..<100).filter { x in
                buffer.pixel(x: origin.0 + x, y: origin.1 + y) & 0x00FF_FFFF != 0
            }.count
        }
    }
    #expect(quadrants.allSatisfy { $0 > 0 }, "stars should appear in all four quadrants: \(quadrants)")
}

@Test func dissolverUsesAndQuantizesTheSourceImage() {
    var began = 0
    let source = PixelColor.rgb(0x13, 0x27, 0xFF)
    let effect = DissolverEffect(hooks: .init(
        sourceImage: { width, height in Array(repeating: source, count: width * height) },
        dissolveBegan: { began += 1 }
    ))
    effect.initialize(width: 10, height: 10)
    effect.update(deltaTime: 0.001)
    let buffer = RenderBuffer(width: 10, height: 10)
    effect.render(into: buffer)
    #expect(began == 1)
    #expect(buffer.pixel(x: 5, y: 5) == PixelColor.rgb(0x10, 0x20, 0xF8))
}

@Test func dissolverFallsBackWhenTheSourceIsTheWrongSize() {
    let effect = DissolverEffect(hooks: .init(sourceImage: { _, _ in [PixelColor.black] }))
    let buffer = run(effect, width: 20, height: 20, seconds: 0.1)
    #expect(litPixelCount(buffer) > 0)
}

@Test func dissolverMovesToTheNextPatternOnceEverythingHasFallen() {
    var ended = 0
    let effect = DissolverEffect(hooks: .init(dissolveEnded: { ended += 1 }), random: FastRandom(seed: 9))
    effect.initialize(width: 16, height: 12)
    #expect(effect.pattern == .topLeft)
    for _ in 0..<(60 * 30) { effect.update(deltaTime: 1.0 / 30) }
    #expect(effect.pattern != .topLeft)
    #expect(ended >= 1)
}

@Test func renderBufferClipsAndBlends() {
    let a = RenderBuffer(width: 2, height: 2)
    a.setPixel(x: -1, y: 0, color: PixelColor.rgb(255, 0, 0))
    a.setPixel(x: 2, y: 2, color: PixelColor.rgb(255, 0, 0))
    #expect(a.pixels.allSatisfy { $0 == PixelColor.black })

    let b = RenderBuffer(width: 2, height: 2)
    b.clear(to: PixelColor.rgb(200, 100, 50))
    a.blend(b, alpha: 1)
    #expect(a.pixel(x: 1, y: 1) == PixelColor.rgb(200, 100, 50))

    a.drawHorizontalLine(fromX: 5, toX: -5, y: 0, color: PixelColor.rgb(1, 2, 3))
    #expect(a.pixel(x: 0, y: 0) == PixelColor.rgb(1, 2, 3))
    #expect(a.pixel(x: 1, y: 0) == PixelColor.rgb(1, 2, 3))

    let image = a.makeImage()
    #expect(image?.width == 2)
}

@Test func palettesHaveTheExpectedEndpoints() {
    let fire = RetroPalette.fire()
    #expect(fire.count == 256)
    #expect(fire[0] == PixelColor.black)
    #expect(fire[255] == PixelColor.rgb(255, 255, 255))
    #expect(RetroPalette.rainbow()[0] == PixelColor.rgb(255, 0, 0))
    #expect(RetroPalette.cga.count == 16)
    #expect(RetroPalette.c64.count == 16)
}

@Test func dissolveSoundIsAValidWAV() {
    let wav = DissolveSound.makeWAV()
    let sampleCount = Int(Double(DissolveSound.sampleRate) * DissolveSound.duration)
    #expect(wav.count == 44 + sampleCount)
    #expect(String(decoding: wav.prefix(4), as: UTF8.self) == "RIFF")
    #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
    #expect(wav == DissolveSound.makeWAV(), "fixed seed: identical every time")
    #expect(DissolveSound.envelope(at: 0) == 0)
    #expect(abs(DissolveSound.envelope(at: 0.65) - 1) < 1e-9)
    #expect(DissolveSound.envelope(at: 1) < 1e-9)
}

@Test func dissolverHooksStayBalanced() {
    var active = 0
    var maxActive = 0
    let effect = DissolverEffect(hooks: .init(
        dissolveBegan: { active += 1; maxActive = max(maxActive, active) },
        dissolveEnded: { active -= 1 }
    ), random: FastRandom(seed: 5))
    effect.initialize(width: 12, height: 8)

    // Ending without a dissolve running fires nothing.
    effect.reset()
    effect.stop()
    #expect(active == 0)

    // Run through several patterns, then stop and reset (which used to double-end).
    for _ in 0..<(120 * 30) { effect.update(deltaTime: 1.0 / 30) }
    effect.stop()
    effect.reset()
    effect.stop()
    #expect(active == 0)
    #expect(maxActive == 1)
}

@Test func randomRangesHandleEdgeCases() {
    var random = FastRandom(seed: 1)
    #expect(random.nextInt(in: 5..<5) == 5)
    #expect(random.nextInt(in: 7..<8) == 7)
    for _ in 0..<1000 {
        #expect((-3..<4).contains(random.nextInt(in: -3..<4)))
        #expect((0..<1).contains(random.nextDouble()))
    }
}
