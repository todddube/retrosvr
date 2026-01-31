using RetroScreensaver.Core;

namespace RetroScreensaver.Effects;

/// <summary>
/// Classic demoscene sine wave scroller effect.
/// Text or bars wave across the screen with rainbow colors.
/// </summary>
public sealed class SineScrollerEffect : IEffect
{
    public string Name => "Sine Scroller";

    private int _width;
    private int _height;
    private double _time;
    private Color[] _palette = Array.Empty<Color>();

    // Simple 8-bit style font (5x7 pixel characters)
    private static readonly Dictionary<char, byte[]> Font = new()
    {
        ['R'] = [0x7C, 0x12, 0x12, 0x12, 0x6C],
        ['E'] = [0x7E, 0x4A, 0x4A, 0x4A, 0x42],
        ['T'] = [0x02, 0x02, 0x7E, 0x02, 0x02],
        ['O'] = [0x3C, 0x42, 0x42, 0x42, 0x3C],
        ['8'] = [0x34, 0x4A, 0x4A, 0x4A, 0x34],
        ['B'] = [0x7E, 0x4A, 0x4A, 0x4A, 0x34],
        ['I'] = [0x00, 0x42, 0x7E, 0x42, 0x00],
        [' '] = [0x00, 0x00, 0x00, 0x00, 0x00],
        ['S'] = [0x24, 0x4A, 0x4A, 0x4A, 0x30],
        ['C'] = [0x3C, 0x42, 0x42, 0x42, 0x24],
        ['N'] = [0x7E, 0x04, 0x08, 0x10, 0x7E],
        ['A'] = [0x7C, 0x12, 0x12, 0x12, 0x7C],
        ['V'] = [0x1E, 0x20, 0x40, 0x20, 0x1E],
        ['!'] = [0x00, 0x00, 0x5E, 0x00, 0x00],
    };

    private const string ScrollText = "RETRO 8BIT SCREENSAVER !!! ";

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _palette = RetroPalette.GenerateRainbowPalette();
        _time = 0;
    }

    public void Update(double deltaTime)
    {
        _time += deltaTime * 60;
    }

    public void Render(RenderBuffer buffer)
    {
        buffer.Clear();

        // Draw background sine wave bars
        DrawBackgroundBars(buffer);

        // Draw scrolling text with sine wave distortion
        DrawScrollText(buffer);

        // Draw bouncing bars at top and bottom
        DrawBouncingBars(buffer);
    }

    private void DrawBackgroundBars(RenderBuffer buffer)
    {
        for (int y = 0; y < _height; y++)
        {
            // Create horizontal color bars with sine wave movement
            double wave = Math.Sin(y * 0.1 + _time * 0.02) * 0.5 + 0.5;
            int colorOffset = (int)(_time * 0.5 + y * 2) % 256;

            for (int x = 0; x < _width; x++)
            {
                // Only draw every few lines for a bar effect
                if (y % 4 < 2)
                {
                    int idx = (colorOffset + x) % 256;
                    Color c = _palette[idx];
                    // Dim the background
                    buffer.SetPixel(x, y, Color.FromArgb(c.R / 6, c.G / 6, c.B / 6));
                }
            }
        }
    }

    private void DrawScrollText(RenderBuffer buffer)
    {
        int charWidth = 6;
        int charHeight = 7;
        int scale = Math.Max(1, _height / 50);
        int textY = _height / 2 - (charHeight * scale) / 2;

        // Calculate scroll position
        int scrollOffset = (int)(_time * 1.5) % (ScrollText.Length * charWidth * scale + _width);

        for (int i = 0; i < ScrollText.Length; i++)
        {
            char c = ScrollText[i];
            if (!Font.TryGetValue(c, out byte[]? charData))
                continue;

            int charX = _width - scrollOffset + i * charWidth * scale;

            // Skip if character is off screen
            if (charX + charWidth * scale < 0 || charX > _width)
                continue;

            // Draw character with sine wave distortion
            for (int cx = 0; cx < 5; cx++)
            {
                byte col = charData[cx];
                for (int cy = 0; cy < 7; cy++)
                {
                    if ((col & (1 << cy)) != 0)
                    {
                        // Apply sine wave distortion
                        double sineOffset = Math.Sin((charX + cx * scale + _time * 2) * 0.05) * (_height * 0.15);
                        int drawX = charX + cx * scale;
                        int drawY = textY + cy * scale + (int)sineOffset;

                        // Rainbow color based on position
                        int colorIdx = (int)(drawX + _time) % 256;
                        if (colorIdx < 0) colorIdx += 256;
                        Color color = _palette[colorIdx];

                        // Draw scaled pixel block
                        for (int sy = 0; sy < scale; sy++)
                        {
                            for (int sx = 0; sx < scale; sx++)
                            {
                                buffer.SetPixel(drawX + sx, drawY + sy, color);
                            }
                        }
                    }
                }
            }
        }
    }

    private void DrawBouncingBars(RenderBuffer buffer)
    {
        int barHeight = 3;

        // Top bouncing bar
        int topBarY = (int)(Math.Sin(_time * 0.08) * 10 + 12);
        for (int x = 0; x < _width; x++)
        {
            int colorIdx = (int)(x + _time * 2) % 256;
            Color c = _palette[colorIdx];
            for (int by = 0; by < barHeight; by++)
            {
                buffer.SetPixel(x, topBarY + by, c);
            }
        }

        // Bottom bouncing bar
        int bottomBarY = _height - (int)(Math.Sin(_time * 0.08 + Math.PI) * 10 + 15);
        for (int x = 0; x < _width; x++)
        {
            int colorIdx = (_width - x + (int)(_time * 2)) % 256;
            if (colorIdx < 0) colorIdx += 256;
            Color c = _palette[colorIdx];
            for (int by = 0; by < barHeight; by++)
            {
                buffer.SetPixel(x, bottomBarY + by, c);
            }
        }
    }

    public void Reset()
    {
        _time = 0;
    }

    public void Dispose() { }
}
