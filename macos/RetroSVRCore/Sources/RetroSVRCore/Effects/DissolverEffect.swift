//
//  DissolverEffect.swift
//  RetroSVRCore · RetroSVR
//
//  Pixelates a source image, then crumbles it into falling particles, one pattern at a time.
//

import Foundation

/// Turns an image into one particle per chunky pixel and lets them fall under gravity,
/// spreading from a corner, the edges or the centre. Then it repeats with the next pattern.
public final class DissolverEffect: Effect {
    /// Platform hooks, so the core stays free of AppKit and audio code.
    public struct Hooks {
        /// Returns `width × height` row-major pixels to dissolve, or `nil` to use the
        /// built-in rainbow pattern. Called at the start of each dissolve.
        public var sourceImage: ((_ width: Int, _ height: Int) -> [UInt32]?)?
        /// Called when a dissolve starts, for example to start the crackle sound.
        public var dissolveBegan: (() -> Void)?
        /// Called once per ``dissolveBegan`` when that dissolve ends or the effect is reset or
        /// stopped.
        public var dissolveEnded: (() -> Void)?

        public init(
            sourceImage: ((_ width: Int, _ height: Int) -> [UInt32]?)? = nil,
            dissolveBegan: (() -> Void)? = nil,
            dissolveEnded: (() -> Void)? = nil
        ) {
            self.sourceImage = sourceImage
            self.dissolveBegan = dissolveBegan
            self.dissolveEnded = dissolveEnded
        }
    }

    /// Where the dissolve starts spreading from; each finished dissolve moves to the next case.
    enum Pattern: Int, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight, edgesIn, centerOut
    }

    private struct Particle {
        var x: Float
        var y: Float
        var velocityX: Float
        var velocityY: Float
        var color: UInt32
        var falling: Bool
        /// The particle starts falling once the dissolve progress passes this.
        var threshold: Float
    }

    /// Dissolve progress gained per second.
    private static let dissolveSpeed = 0.15
    /// Downward acceleration, in chunky pixels per second².
    private static let gravity = 120.0
    /// Progress after which every particle has started falling (largest threshold is 4.2).
    private static let allFallingProgress = 5.0
    /// Horizontal velocity kept per second. Windows kept 0.99 per frame at 30 fps.
    private static let dragPerSecond = pow(0.99, 30.0)

    public let kind = EffectKind.dissolver
    public var hooks: Hooks

    private var width = 0
    private var height = 0
    private var particles: [Particle] = []
    private var random: FastRandom
    private var progress = 0.0
    private var captured = false
    /// Whether ``Hooks/dissolveBegan`` has fired without a matching ``Hooks/dissolveEnded``.
    /// Keeps the two balanced so the shared sound player's count stays right.
    private var dissolveActive = false
    private(set) var pattern = Pattern.topLeft

    public init(hooks: Hooks = .init(), random: FastRandom = FastRandom()) {
        self.hooks = hooks
        self.random = random
    }

    public func initialize(width: Int, height: Int) {
        self.width = width
        self.height = height
        particles = []
        progress = 0
        captured = false
        pattern = .topLeft
    }

    public func update(deltaTime: Double) {
        if !captured {
            capture()
            captured = true
            dissolveActive = true
            hooks.dissolveBegan?()
        }

        progress += Self.dissolveSpeed * deltaTime
        let drag = Float(pow(Self.dragPerSecond, deltaTime))
        let gravityStep = Float(Self.gravity * deltaTime)
        let dt = Float(deltaTime)
        let progress = Float(self.progress)

        for i in particles.indices {
            if !particles[i].falling, progress >= particles[i].threshold {
                // A small upward pop before gravity takes over.
                particles[i].falling = true
                particles[i].velocityY = -Float(random.nextInt(in: 20..<60))
                particles[i].velocityX = Float(random.nextInt(in: -30..<31))
            }
            if particles[i].falling {
                particles[i].velocityY += gravityStep
                particles[i].velocityX *= drag
                particles[i].x += particles[i].velocityX * dt
                particles[i].y += particles[i].velocityY * dt
            }
        }

        if self.progress > Self.allFallingProgress,
           !particles.contains(where: { $0.y < Float(height + 10) }) {
            advancePattern()
        }
    }

    private func endDissolve() {
        guard dissolveActive else { return }
        dissolveActive = false
        hooks.dissolveEnded?()
    }

    private func advancePattern() {
        endDissolve()
        pattern = Pattern(rawValue: (pattern.rawValue + 1) % Pattern.allCases.count) ?? .topLeft
        progress = 0
        captured = false
        particles = []
    }

    private func capture() {
        let count = width * height
        let source = hooks.sourceImage?(width, height).flatMap { $0.count == count ? $0 : nil }
        let pixels: [UInt32] = if let source {
            // Quantize to 32 levels per channel for an 8-bit feel.
            source.map { PixelColor.rgb(PixelColor.red($0) / 8 * 8, PixelColor.green($0) / 8 * 8, PixelColor.blue($0) / 8 * 8) }
        } else {
            Self.fallbackPattern(width: width, height: height)
        }

        particles = []
        particles.reserveCapacity(count)
        for y in 0..<height {
            for x in 0..<width {
                particles.append(Particle(
                    x: Float(x), y: Float(y), velocityX: 0, velocityY: 0,
                    color: pixels[y * width + x], falling: false,
                    threshold: threshold(x: x, y: y)
                ))
            }
        }
    }

    /// A rainbow wave used when no source image is available.
    static func fallbackPattern(width: Int, height: Int) -> [UInt32] {
        let palette = RetroPalette.rainbow()
        var pixels: [UInt32] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                var index = (x + y * 2 + Int(sin(Double(x) * 0.1) * 20)) % 256
                if index < 0 { index += 256 }
                pixels.append(palette[index])
            }
        }
        return pixels
    }

    /// When the particle at (`x`, `y`) starts falling: its normalised distance from the
    /// pattern's origin, plus jitter so the front is ragged.
    private func threshold(x: Int, y: Int) -> Float {
        let w = Float(width)
        let h = Float(height)
        let fx = Float(x)
        let fy = Float(y)
        let diagonal = (w * w + h * h).squareRoot()
        let jitter = Float(random.nextDouble()) * 1.2

        func cornerDistance(_ cx: Float, _ cy: Float) -> Float {
            ((fx - cx) * (fx - cx) + (fy - cy) * (fy - cy)).squareRoot() / diagonal * 3 + jitter
        }

        switch pattern {
        case .topLeft: return cornerDistance(0, 0)
        case .topRight: return cornerDistance(w, 0)
        case .bottomLeft: return cornerDistance(0, h)
        case .bottomRight: return cornerDistance(w, h)
        case .edgesIn:
            let edge = min(min(fx, w - fx), min(fy, h - fy))
            return edge / (min(w, h) / 2) * 2.5 + jitter
        case .centerOut:
            let cx = w / 2
            let cy = h / 2
            let distance = ((fx - cx) * (fx - cx) + (fy - cy) * (fy - cy)).squareRoot()
            return distance / (cx * cx + cy * cy).squareRoot() * 2.5 + jitter
        }
    }

    public func render(into buffer: RenderBuffer) {
        buffer.clear()
        for particle in particles {
            // Truncate toward zero like the original, so particles leave the left and top
            // edges a pixel late.
            buffer.setPixel(x: Int(particle.x), y: Int(particle.y), color: particle.color)
        }
    }

    public func reset() {
        endDissolve()
        progress = 0
        captured = false
        pattern = .topLeft
        particles = []
    }

    public func stop() {
        endDissolve()
    }
}
