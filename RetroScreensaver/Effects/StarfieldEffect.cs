using RetroScreensaver.Core;

namespace RetroScreensaver.Effects;

/// <summary>
/// Classic Windows 3.1 style starfield flying through space.
/// Stars move from center outward, creating depth illusion.
/// </summary>
public sealed class StarfieldEffect : IEffect
{
    private struct Star
    {
        public double X;
        public double Y;
        public double Z;
        public double Speed;
    }

    public string Name => "Starfield";

    private Star[] _stars = Array.Empty<Star>();
    private int _width;
    private int _height;
    private int _centerX;
    private int _centerY;
    private readonly Random _random = new();
    private readonly Color[] _palette;
    private double _warpFactor = 1.0;
    private double _warpDirection = 0.01;

    public StarfieldEffect()
    {
        _palette = RetroPalette.GenerateStarfieldPalette();
    }

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _centerX = width / 2;
        _centerY = height / 2;

        // Create stars based on screen size
        int starCount = Math.Max(100, (width * height) / 200);
        _stars = new Star[starCount];

        for (int i = 0; i < _stars.Length; i++)
        {
            ResetStar(ref _stars[i], true);
        }
    }

    private void ResetStar(ref Star star, bool randomZ = false)
    {
        // Random position in 3D space
        star.X = (_random.NextDouble() - 0.5) * _width * 2;
        star.Y = (_random.NextDouble() - 0.5) * _height * 2;
        star.Z = randomZ ? _random.NextDouble() * 1000 : 1000;
        star.Speed = 0.5 + _random.NextDouble() * 1.5;
    }

    public void Update(double deltaTime)
    {
        // Subtle warp speed variation for fluid movement
        _warpFactor += _warpDirection;
        if (_warpFactor > 2.0 || _warpFactor < 0.5)
        {
            _warpDirection = -_warpDirection;
        }

        double movement = deltaTime * 200 * _warpFactor;

        for (int i = 0; i < _stars.Length; i++)
        {
            _stars[i].Z -= movement * _stars[i].Speed;

            // Reset star when it passes the viewer
            if (_stars[i].Z <= 1)
            {
                ResetStar(ref _stars[i]);
            }
        }
    }

    public void Render(RenderBuffer buffer)
    {
        buffer.Clear();

        for (int i = 0; i < _stars.Length; i++)
        {
            ref Star star = ref _stars[i];

            // Project 3D to 2D
            double scale = 500.0 / star.Z;
            int screenX = (int)(star.X * scale) + _centerX;
            int screenY = (int)(star.Y * scale) + _centerY;

            if (screenX < 0 || screenX >= _width || screenY < 0 || screenY >= _height)
                continue;

            // Calculate brightness based on depth (closer = brighter)
            int brightness = (int)(255 - (star.Z / 1000.0 * 255));
            brightness = Math.Clamp(brightness, 32, 255);

            Color color = _palette[brightness];

            // Draw star - larger when closer
            if (star.Z < 200)
            {
                // Draw a 2x2 block for close stars
                buffer.SetPixel(screenX, screenY, color);
                buffer.SetPixel(screenX + 1, screenY, color);
                buffer.SetPixel(screenX, screenY + 1, color);
                buffer.SetPixel(screenX + 1, screenY + 1, color);
            }
            else if (star.Z < 500)
            {
                // Draw cross for medium distance
                buffer.SetPixel(screenX, screenY, color);
                buffer.SetPixel(screenX - 1, screenY, Color.FromArgb(color.A, color.R / 2, color.G / 2, color.B / 2));
                buffer.SetPixel(screenX + 1, screenY, Color.FromArgb(color.A, color.R / 2, color.G / 2, color.B / 2));
            }
            else
            {
                // Single pixel for distant stars
                buffer.SetPixel(screenX, screenY, color);
            }

            // Optional: draw streak/trail for warp effect
            if (_warpFactor > 1.5 && star.Z < 400)
            {
                int trailLength = (int)((500 - star.Z) / 100 * _warpFactor);
                double dirX = star.X / Math.Max(1, Math.Abs(star.X) + Math.Abs(star.Y));
                double dirY = star.Y / Math.Max(1, Math.Abs(star.X) + Math.Abs(star.Y));

                for (int t = 1; t <= trailLength; t++)
                {
                    int tx = screenX - (int)(dirX * t);
                    int ty = screenY - (int)(dirY * t);
                    int trailBrightness = brightness - t * 30;
                    if (trailBrightness > 0)
                    {
                        buffer.SetPixel(tx, ty, _palette[Math.Clamp(trailBrightness, 0, 255)]);
                    }
                }
            }
        }
    }

    public void Reset()
    {
        for (int i = 0; i < _stars.Length; i++)
        {
            ResetStar(ref _stars[i], true);
        }
        _warpFactor = 1.0;
    }

    public void Dispose() { }
}
