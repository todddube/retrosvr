using RetroScreensaver.Core;

namespace RetroScreensaver.Effects;

/// <summary>
/// Classic demoscene plasma effect using sine wave combinations.
/// Creates organic, flowing color patterns.
/// </summary>
public sealed class PlasmaEffect : IEffect
{
    public string Name => "Plasma";

    private int _width;
    private int _height;
    private Color[] _palette = Array.Empty<Color>();
    private double _time;
    private double[] _sinTable = Array.Empty<double>();
    private double[] _cosTable = Array.Empty<double>();

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _palette = RetroPalette.GeneratePlasmaPalette();
        _time = 0;

        // Pre-calculate sin/cos tables for performance
        _sinTable = new double[1024];
        _cosTable = new double[1024];
        for (int i = 0; i < 1024; i++)
        {
            double angle = i * Math.PI * 2 / 1024;
            _sinTable[i] = Math.Sin(angle);
            _cosTable[i] = Math.Cos(angle);
        }
    }

    public void Update(double deltaTime)
    {
        _time += deltaTime * 50;
    }

    public void Render(RenderBuffer buffer)
    {
        int timeInt = (int)_time;

        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                // Classic plasma formula using multiple sine waves
                double value = 0;

                // Wave 1: Diagonal sweep
                value += Sin((x + timeInt) * 0.08);

                // Wave 2: Horizontal wave
                value += Sin((y + timeInt * 0.5) * 0.06);

                // Wave 3: Circular ripple from center
                double cx = x - _width / 2.0;
                double cy = y - _height / 2.0;
                double dist = Math.Sqrt(cx * cx + cy * cy);
                value += Sin((dist - timeInt * 0.8) * 0.1);

                // Wave 4: Diagonal interference pattern
                value += Sin((x * 0.05 + y * 0.05 + timeInt * 0.3) * 0.9);

                // Wave 5: Rotating pattern
                double angle = Math.Atan2(cy, cx);
                value += Sin((angle * 4 + timeInt * 0.1) * 0.5);

                // Normalize to palette index (0-255)
                int colorIndex = (int)((value + 5) * 25.5) % 256;
                if (colorIndex < 0) colorIndex += 256;

                buffer.SetPixel(x, y, _palette[colorIndex]);
            }
        }
    }

    private double Sin(double x)
    {
        int index = ((int)(x * 162.97) & 1023);
        return _sinTable[index];
    }

    private double Cos(double x)
    {
        int index = ((int)(x * 162.97) & 1023);
        return _cosTable[index];
    }

    public void Reset()
    {
        _time = 0;
    }

    public void Dispose() { }
}
