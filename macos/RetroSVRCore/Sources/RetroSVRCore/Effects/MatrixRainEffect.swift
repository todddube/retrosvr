//
//  MatrixRainEffect.swift
//  RetroSVRCore · RetroSVR
//
//  Matrix-style digital rain: one falling green streak per pixel column.
//

/// Falling streaks with bright heads and fading tails, plus random glitch pixels.
///
/// The Windows version also stored a random "character" per streak cell, but never drew
/// them, so they're left out here.
public final class MatrixRainEffect: Effect {
    private struct Column {
        var y: Double
        var speed: Double
        var length: Int
    }

    private static let headColor = PixelColor.rgb(200, 255, 200)

    public let kind = EffectKind.matrixRain

    private var width = 0
    private var height = 0
    private var columns: [Column] = []
    private let palette = RetroPalette.matrix()
    private var random: FastRandom

    public init(random: FastRandom = FastRandom()) {
        self.random = random
    }

    public func initialize(width: Int, height: Int) {
        self.width = width
        self.height = height
        columns = (0..<width).map { _ in makeStaggeredColumn() }
    }

    private func makeColumn() -> Column {
        let length = random.nextInt(in: 5..<max(6, height / 3))
        return Column(y: -Double(length), speed: 5 + random.nextDouble() * 15, length: length)
    }

    /// A new column at a random height above the screen, so streaks don't arrive together.
    private func makeStaggeredColumn() -> Column {
        var column = makeColumn()
        column.y = -Double(random.nextInt(in: 0..<height))
        return column
    }

    public func update(deltaTime: Double) {
        for i in columns.indices {
            columns[i].y += columns[i].speed * deltaTime
            if columns[i].y - Double(columns[i].length) > Double(height) {
                columns[i] = makeColumn()
            }
        }
    }

    public func render(into buffer: RenderBuffer) {
        buffer.clear()

        for (x, column) in columns.enumerated() {
            let headY = Int(column.y)
            for i in 0..<column.length {
                let y = headY - i
                guard y >= 0, y < height else { continue }
                if i == 0 {
                    buffer.setPixel(x: x, y: y, color: Self.headColor)
                } else {
                    let fade = 1 - Double(i) / Double(column.length)
                    buffer.setPixel(x: x, y: y, color: palette[Int(fade * 200).clamped(to: 0...255)])
                }
            }
        }

        // Glitch pixels for atmosphere.
        for _ in 0..<(width / 20) {
            let x = random.nextInt(in: 0..<width)
            let y = random.nextInt(in: 0..<height)
            if random.nextDouble() < 0.5 {
                buffer.setPixel(x: x, y: y, color: palette[random.nextInt(in: 50..<150)])
            }
        }
    }

    public func reset() {
        columns = (0..<width).map { _ in makeStaggeredColumn() }
    }
}
