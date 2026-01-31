using RetroScreensaver.Core;

namespace RetroScreensaver.Effects;

/// <summary>
/// Captures the current screen, scales to 8-bit style, and dissolves into falling particles.
/// Cycles through different dissolution patterns (corners, edges, center).
/// </summary>
public sealed class DissolverEffect : IEffect
{
    public string Name => "Dissolver";

    private int _width;
    private int _height;
    private Particle[] _particles = [];
    private int[] _capturedPixels = [];
    private readonly Random _random = new();
    private double _dissolveProgress;
    private bool _screenCaptured;
    private int _currentPattern;
    private const int PatternCount = 6; // Number of dissolution patterns
    private const double DissolveSpeed = 0.15; // How fast dissolution spreads
    private const double Gravity = 120.0; // Pixels per second squared

    private enum DissolvePattern
    {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight,
        EdgesIn,
        CenterOut
    }

    private struct Particle
    {
        public float X;
        public float Y;
        public float VelocityX;
        public float VelocityY;
        public int Color;
        public int OriginalX;
        public int OriginalY;
        public bool Falling;
        public float DissolveThreshold; // When dissolveProgress exceeds this, particle falls
    }

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _particles = new Particle[_width * _height];
        _capturedPixels = new int[_width * _height];
        _dissolveProgress = 0;
        _screenCaptured = false;
        _currentPattern = 0;
    }

    public void Update(double deltaTime)
    {
        // Capture screen on first update
        if (!_screenCaptured)
        {
            CaptureScreen();
            _screenCaptured = true;
        }

        // Advance dissolution
        _dissolveProgress += DissolveSpeed * deltaTime;

        // Update particles
        for (int i = 0; i < _particles.Length; i++)
        {
            ref var p = ref _particles[i];

            // Check if this particle should start falling
            if (!p.Falling && _dissolveProgress >= p.DissolveThreshold)
            {
                p.Falling = true;
                // Give initial velocity - slight upward burst then fall
                p.VelocityY = -_random.Next(20, 60);
                p.VelocityX = _random.Next(-30, 31);
            }

            if (p.Falling)
            {
                // Apply gravity
                p.VelocityY += (float)(Gravity * deltaTime);

                // Apply some air resistance to horizontal movement
                p.VelocityX *= 0.99f;

                // Update position
                p.X += (float)(p.VelocityX * deltaTime);
                p.Y += (float)(p.VelocityY * deltaTime);
            }
        }

        // Reset when all particles have fallen off screen
        if (_dissolveProgress > 5.0)
        {
            bool allGone = true;
            for (int i = 0; i < _particles.Length; i++)
            {
                if (_particles[i].Y < _height + 10)
                {
                    allGone = false;
                    break;
                }
            }

            if (allGone)
            {
                CycleToNextPattern();
            }
        }
    }

    private void CycleToNextPattern()
    {
        // Move to next pattern
        _currentPattern = (_currentPattern + 1) % PatternCount;

        // Reset state for new capture
        _dissolveProgress = 0;
        _screenCaptured = false;

        // Clear particles
        for (int i = 0; i < _particles.Length; i++)
        {
            _particles[i] = default;
        }
    }

    private void CaptureScreen()
    {
        try
        {
            // Get the primary screen bounds
            var screen = Screen.PrimaryScreen;
            if (screen == null)
            {
                FillWithPattern();
                return;
            }

            var bounds = screen.Bounds;

            // Capture the screen
            using var screenBitmap = new Bitmap(bounds.Width, bounds.Height);
            using (var g = Graphics.FromImage(screenBitmap))
            {
                g.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);
            }

            // Scale down to our 8-bit resolution
            using var scaledBitmap = new Bitmap(_width, _height);
            using (var g = Graphics.FromImage(scaledBitmap))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
                g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
                g.DrawImage(screenBitmap, 0, 0, _width, _height);
            }

            // Reduce colors to give it an 8-bit feel
            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    var pixel = scaledBitmap.GetPixel(x, y);

                    // Quantize to fewer colors (32 levels per channel = 32768 colors)
                    int r = (pixel.R / 8) * 8;
                    int g = (pixel.G / 8) * 8;
                    int b = (pixel.B / 8) * 8;

                    int color = unchecked((int)(0xFF000000u | ((uint)r << 16) | ((uint)g << 8) | (uint)b));
                    _capturedPixels[y * _width + x] = color;

                    InitializeParticle(x, y, color);
                }
            }
        }
        catch
        {
            // If screen capture fails, use a colorful pattern
            FillWithPattern();
        }
    }

    private void FillWithPattern()
    {
        // Create a colorful 8-bit pattern as fallback
        var palette = RetroPalette.GenerateRainbowPalette();

        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                // Create a plasma-like pattern
                int idx = (x + y * 2 + (int)(Math.Sin(x * 0.1) * 20)) % 256;
                if (idx < 0) idx += 256;

                var c = palette[idx];
                int color = unchecked((int)(0xFF000000u | ((uint)c.R << 16) | ((uint)c.G << 8) | (uint)c.B));
                _capturedPixels[y * _width + x] = color;

                InitializeParticle(x, y, color);
            }
        }
    }

    private void InitializeParticle(int x, int y, int color)
    {
        int i = y * _width + x;
        float threshold = CalculateDissolveThreshold(x, y);

        _particles[i] = new Particle
        {
            X = x,
            Y = y,
            VelocityX = 0,
            VelocityY = 0,
            Color = color,
            OriginalX = x,
            OriginalY = y,
            Falling = false,
            DissolveThreshold = threshold
        };
    }

    private float CalculateDissolveThreshold(int x, int y)
    {
        float threshold;
        float maxDist = (float)Math.Sqrt(_width * _width + _height * _height);
        float randomness = (float)_random.NextDouble() * 1.2f;

        switch ((DissolvePattern)_currentPattern)
        {
            case DissolvePattern.TopLeft:
                // Distance from top-left corner
                float distTL = (float)Math.Sqrt(x * x + y * y);
                threshold = (distTL / maxDist) * 3.0f + randomness;
                break;

            case DissolvePattern.TopRight:
                // Distance from top-right corner
                float distTR = (float)Math.Sqrt((_width - x) * (_width - x) + y * y);
                threshold = (distTR / maxDist) * 3.0f + randomness;
                break;

            case DissolvePattern.BottomLeft:
                // Distance from bottom-left corner
                float distBL = (float)Math.Sqrt(x * x + (_height - y) * (_height - y));
                threshold = (distBL / maxDist) * 3.0f + randomness;
                break;

            case DissolvePattern.BottomRight:
                // Distance from bottom-right corner
                float distBR = (float)Math.Sqrt((_width - x) * (_width - x) + (_height - y) * (_height - y));
                threshold = (distBR / maxDist) * 3.0f + randomness;
                break;

            case DissolvePattern.EdgesIn:
                // Distance from nearest edge - edges dissolve first
                float distLeft = x;
                float distRight = _width - x;
                float distTop = y;
                float distBottom = _height - y;
                float minEdgeDist = Math.Min(Math.Min(distLeft, distRight), Math.Min(distTop, distBottom));
                float maxEdgeDist = Math.Min(_width, _height) / 2f;
                threshold = (minEdgeDist / maxEdgeDist) * 2.5f + randomness;
                break;

            case DissolvePattern.CenterOut:
            default:
                // Distance from center - center dissolves first
                float centerX = _width / 2f;
                float centerY = _height / 2f;
                float distFromCenter = (float)Math.Sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
                float maxCenterDist = (float)Math.Sqrt(centerX * centerX + centerY * centerY);
                threshold = (distFromCenter / maxCenterDist) * 2.5f + randomness;
                break;
        }

        return threshold;
    }

    public void Render(RenderBuffer buffer)
    {
        buffer.Clear();

        // Draw particles
        for (int i = 0; i < _particles.Length; i++)
        {
            ref var p = ref _particles[i];

            int drawX, drawY;

            if (p.Falling)
            {
                drawX = (int)p.X;
                drawY = (int)p.Y;
            }
            else
            {
                drawX = p.OriginalX;
                drawY = p.OriginalY;
            }

            // Only draw if on screen
            if (drawX >= 0 && drawX < _width && drawY >= 0 && drawY < _height)
            {
                buffer.SetPixel(drawX, drawY, p.Color);
            }
        }
    }

    public void Reset()
    {
        _dissolveProgress = 0;
        _screenCaptured = false;
        _currentPattern = 0; // Start from first pattern on manual reset

        // Clear particles
        for (int i = 0; i < _particles.Length; i++)
        {
            _particles[i] = default;
        }
    }

    public void Dispose() { }
}
