using RetroScreensaver.Core;

namespace RetroScreensaver.Effects;

/// <summary>
/// Classic demoscene fire effect.
/// Heat rises from bottom, cooling as it goes up.
/// </summary>
public sealed class FireEffect : IEffect
{
    public string Name => "Fire";

    private int _width;
    private int _height;
    private int[] _fireBuffer = Array.Empty<int>();
    private Color[] _palette = Array.Empty<Color>();
    private readonly Random _random = new();
    private double _intensity = 1.0;
    private double _intensityDir = 0.002;

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _fireBuffer = new int[_width * _height];
        _palette = RetroPalette.GenerateFirePalette();
        _intensity = 1.0;
    }

    public void Update(double deltaTime)
    {
        // Vary intensity for dynamic flames
        _intensity += _intensityDir;
        if (_intensity > 1.3 || _intensity < 0.7)
        {
            _intensityDir = -_intensityDir;
        }

        // Set random fire source at bottom
        int bottomRow = (_height - 1) * _width;
        for (int x = 0; x < _width; x++)
        {
            // Random hot spots at the bottom
            if (_random.NextDouble() < 0.6)
            {
                _fireBuffer[bottomRow + x] = (int)((_random.Next(200, 256)) * _intensity);
            }
            else
            {
                _fireBuffer[bottomRow + x] = (int)(_random.Next(100, 200) * _intensity);
            }
        }

        // Also set second-to-bottom row for more fire volume
        int secondRow = (_height - 2) * _width;
        for (int x = 0; x < _width; x++)
        {
            if (_random.NextDouble() < 0.4)
            {
                _fireBuffer[secondRow + x] = (int)(_random.Next(180, 256) * _intensity);
            }
        }

        // Propagate fire upward with cooling
        for (int y = 0; y < _height - 2; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                // Sample neighboring pixels from row below
                int below = (y + 1) * _width;
                int belowBelow = (y + 2) * _width;

                int sum = 0;
                int count = 0;

                // Sample from row below
                if (x > 0) { sum += _fireBuffer[below + x - 1]; count++; }
                sum += _fireBuffer[below + x]; count++;
                if (x < _width - 1) { sum += _fireBuffer[below + x + 1]; count++; }

                // Sample from two rows below for smoother flames
                sum += _fireBuffer[belowBelow + x]; count++;

                // Average with heat retention to prevent too-fast decay
                int newValue = (sum * 5) / (count * 4); // Boost by 1.25x to counteract averaging

                // Cooling factor - flames die out as they rise
                int cooling = _random.Next(0, 3); // Reduced cooling (0-2 instead of 1-3)
                newValue = Math.Clamp(newValue - cooling, 0, 255);

                _fireBuffer[y * _width + x] = newValue;
            }
        }
    }

    public void Render(RenderBuffer buffer)
    {
        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                int colorIndex = Math.Clamp(_fireBuffer[y * _width + x], 0, 255);
                buffer.SetPixel(x, y, _palette[colorIndex]);
            }
        }
    }

    public void Reset()
    {
        Array.Clear(_fireBuffer, 0, _fireBuffer.Length);
        _intensity = 1.0;
    }

    public void Dispose() { }
}
