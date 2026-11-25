//
//  StarfieldEffect.swift
//  RetroSVRCore · RetroSVR
//
//  Windows 3.1-style flight through a 3D starfield with a pulsing warp speed.
//

/// Stars stream outward from the centre; near stars grow and, at high warp, leave trails.
public final class StarfieldEffect: Effect {
    private struct Star {
        var x: Double
        var y: Double
        var z: Double
        var speed: Double
    }

    /// Warp change per second. Windows added 0.01 per frame at its default 30 fps.
    private static let warpRate = 0.3
    private static let farPlane = 1000.0

    public let kind = EffectKind.starfield

    private var stars: [Star] = []
    private var width = 0
    private var height = 0
    private var random: FastRandom
    private let palette = RetroPalette.starfield()
    private var warpFactor = 1.0
    private var warpDirection = 1.0

    public init(random: FastRandom = FastRandom()) {
        self.random = random
    }

    public func initialize(width: Int, height: Int) {
        self.width = width
        self.height = height
        let count = max(100, width * height / 200)
        stars = (0..<count).map { _ in makeStar(randomDepth: true) }
    }

    private func makeStar(randomDepth: Bool) -> Star {
        Star(
            x: (random.nextDouble() - 0.5) * Double(width) * 2,
            y: (random.nextDouble() - 0.5) * Double(height) * 2,
            z: randomDepth ? random.nextDouble() * Self.farPlane : Self.farPlane,
            speed: 0.5 + random.nextDouble() * 1.5
        )
    }

    public func update(deltaTime: Double) {
        warpFactor += warpDirection * Self.warpRate * deltaTime
        // Set the direction rather than flipping it, so a long frame can't leave it stuck
        // flipping back and forth outside the range.
        if warpFactor > 2.0 {
            warpDirection = -1
        } else if warpFactor < 0.5 {
            warpDirection = 1
        }

        let movement = deltaTime * 200 * warpFactor
        for i in stars.indices {
            stars[i].z -= movement * stars[i].speed
            if stars[i].z <= 1 {
                stars[i] = makeStar(randomDepth: false)
            }
        }
    }

    public func render(into buffer: RenderBuffer) {
        buffer.clear()
        let centerX = width / 2
        let centerY = height / 2

        for star in stars {
            let projection = 500.0 / star.z
            let screenX = Int(star.x * projection) + centerX
            let screenY = Int(star.y * projection) + centerY
            guard screenX >= 0, screenX < width, screenY >= 0, screenY < height else { continue }

            let brightness = Int(255 - star.z / Self.farPlane * 255).clamped(to: 32...255)
            let color = palette[brightness]

            if star.z < 200 {
                // Close: 2×2 block.
                buffer.setPixel(x: screenX, y: screenY, color: color)
                buffer.setPixel(x: screenX + 1, y: screenY, color: color)
                buffer.setPixel(x: screenX, y: screenY + 1, color: color)
                buffer.setPixel(x: screenX + 1, y: screenY + 1, color: color)
            } else if star.z < 500 {
                // Medium: a dim horizontal flare either side.
                let dim = PixelColor.dimmed(color, by: 2)
                buffer.setPixel(x: screenX, y: screenY, color: color)
                buffer.setPixel(x: screenX - 1, y: screenY, color: dim)
                buffer.setPixel(x: screenX + 1, y: screenY, color: dim)
            } else {
                buffer.setPixel(x: screenX, y: screenY, color: color)
            }

            if warpFactor > 1.5, star.z < 400 {
                let trailLength = Int((500 - star.z) / 100 * warpFactor)
                let norm = max(1, abs(star.x) + abs(star.y))
                let dirX = star.x / norm
                let dirY = star.y / norm
                guard trailLength >= 1 else { continue }
                for t in 1...trailLength {
                    let trailBrightness = brightness - t * 30
                    guard trailBrightness > 0 else { break }
                    buffer.setPixel(
                        x: screenX - Int(dirX * Double(t)),
                        y: screenY - Int(dirY * Double(t)),
                        color: palette[trailBrightness]
                    )
                }
            }
        }
    }

    public func reset() {
        for i in stars.indices {
            stars[i] = makeStar(randomDepth: true)
        }
        warpFactor = 1.0
    }
}
