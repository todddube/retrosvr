//
//  FireEffect.swift
//  RetroSVRCore · RetroSVR
//
//  Classic demoscene fire: heat seeded along the bottom rises, spreads and cools.
//

/// A heat-map fire simulation drawn through a black-to-white fire palette.
///
/// Each step, every cell averages the cells below it and subtracts cooling read from a
/// smooth noise texture that scrolls upward with the flames. That moving texture is what
/// carves flame tongues. Independent per-cell noise just averages away into a flat band.
///
/// Windows boosted the average by 1.25× instead of cooling it this way. That only looked
/// right through the oversized-buffer bug. At the true buffer size, every cell above heat
/// 4 grows until the screen is a white wall.
public final class FireEffect: Effect {
    /// Simulation step length. Windows stepped once per rendered frame at a default 30 fps,
    /// so flames rose twice as fast at 60 fps; a fixed step keeps the look at any frame rate.
    static let stepInterval = 1.0 / 30.0
    /// Intensity drift per step, bouncing between 0.7 and 1.3 for breathing flames.
    private static let intensityStep = 0.002
    /// Roughly the fraction of the buffer height the flames reach.
    private static let flameHeight = 0.6
    /// Box-blur passes over the cooling noise; more passes make bigger, softer cool patches.
    private static let coolingBlurPasses = 6

    public let kind = EffectKind.fire

    private var width = 0
    private var height = 0
    private var heat: [Int] = []
    /// Per-cell cooling amounts, averaging the cooling needed to reach ``flameHeight``.
    private var coolingMap: [Double] = []
    private var coolingOffset = 0
    private let palette = RetroPalette.fire()
    private var random: FastRandom
    private var intensity = 1.0
    private var intensityDirection = 1.0
    private var accumulator = 0.0
    /// Number of simulation steps run so far; lets tests check frame-rate independence.
    private(set) var stepCount = 0

    public init(random: FastRandom = FastRandom()) {
        self.random = random
    }

    public func initialize(width: Int, height: Int) {
        self.width = width
        self.height = height
        heat = Array(repeating: 0, count: width * height)
        // Full heat should be used up `flameHeight` of the way up. Heat climbs about 1.5 rows
        // per step (the two-rows-down sample speeds it up), so spread 255 over those steps.
        let averageCooling = 255 * 1.5 / (Double(max(height, 1)) * Self.flameHeight)
        coolingMap = makeCoolingMap(averageCooling: averageCooling)
        coolingOffset = 0
        intensity = 1.0
        accumulator = 0
    }

    /// Smooth, wrap-around noise rescaled so cool patches separate mostly-uncooled gaps,
    /// with the mean cooling equal to `averageCooling`.
    private func makeCoolingMap(averageCooling: Double) -> [Double] {
        let count = width * height
        guard count > 0 else { return [] }
        var map = (0..<count).map { _ in random.nextDouble() }
        var scratch = map
        for _ in 0..<Self.coolingBlurPasses {
            for y in 0..<height {
                let up = ((y + height - 1) % height) * width
                let row = y * width
                let down = ((y + 1) % height) * width
                for x in 0..<width {
                    let left = (x + width - 1) % width
                    let right = (x + 1) % width
                    var sum = 0.0
                    for r in [up, row, down] {
                        sum += map[r + left] + map[r + x] + map[r + right]
                    }
                    scratch[row + x] = sum / 9
                }
            }
            swap(&map, &scratch)
        }

        let low = map.min() ?? 0
        let high = map.max() ?? 1
        let range = max(high - low, .ulpOfOne)
        // Values below 30% of the range don't cool at all; above that, cooling ramps up.
        let factors = map.map { max(0, ($0 - low) / range - 0.3) }
        let mean = max(factors.reduce(0, +) / Double(count), .ulpOfOne)
        return factors.map { $0 / mean * averageCooling }
    }

    public func update(deltaTime: Double) {
        accumulator += deltaTime
        while accumulator >= Self.stepInterval {
            accumulator -= Self.stepInterval
            step()
        }
    }

    private func step() {
        stepCount += 1
        intensity += intensityDirection * Self.intensityStep
        if intensity > 1.3 {
            intensityDirection = -1
        } else if intensity < 0.7 {
            intensityDirection = 1
        }
        guard width > 0, height > 0 else { return }

        let width = self.width
        let height = self.height
        let intensity = self.intensity
        // Scroll the cooling texture up one row per step, roughly with the rising heat.
        coolingOffset = (coolingOffset + 1) % height
        let offset = coolingOffset
        coolingMap.withUnsafeBufferPointer { cooling in
            heat.withUnsafeMutableBufferPointer { heat in
                // Seed the bottom row with random hot spots.
                let bottom = (height - 1) * width
                for x in 0..<width {
                    let range = random.nextDouble() < 0.6 ? 200..<256 : 100..<200
                    heat[bottom + x] = Int(Double(random.nextInt(in: range)) * intensity)
                }

                // Extra sparks one row up give the flames more body.
                if height >= 2 {
                    let second = (height - 2) * width
                    for x in 0..<width where random.nextDouble() < 0.4 {
                        heat[second + x] = Int(Double(random.nextInt(in: 180..<256)) * intensity)
                    }
                }

                guard height >= 3 else { return }
                for y in 0..<(height - 2) {
                    let row = y * width
                    let below = row + width
                    let belowBelow = below + width
                    let coolingRow = ((y + offset) % height) * width
                    for x in 0..<width {
                        // A random ±1 column shift adds flicker to the tongues' edges.
                        let sx = (x + random.nextInt(in: -1..<2)).clamped(to: 0...(width - 1))
                        var sum = heat[below + sx] + heat[belowBelow + sx]
                        var count = 2
                        if sx > 0 { sum += heat[below + sx - 1]; count += 1 }
                        if sx < width - 1 { sum += heat[below + sx + 1]; count += 1 }

                        // Random dither keeps fractional cooling from rounding away.
                        let amount = Int(cooling[coolingRow + x] + random.nextDouble())
                        heat[row + x] = (sum / count - amount).clamped(to: 0...255)
                    }
                }
            }
        }
    }

    public func render(into buffer: RenderBuffer) {
        guard buffer.width == width, buffer.height == height else { return }
        buffer.pixels.withUnsafeMutableBufferPointer { pixels in
            for i in 0..<pixels.count {
                pixels[i] = palette[heat[i].clamped(to: 0...255)]
            }
        }
    }

    public func reset() {
        heat = Array(repeating: 0, count: width * height)
        coolingOffset = 0
        intensity = 1.0
        accumulator = 0
    }
}
