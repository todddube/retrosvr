namespace RetroScreensaver.Core;

/// <summary>
/// Classic 8-bit color palettes for authentic retro aesthetics.
/// </summary>
public static class RetroPalette
{
    // Classic CGA palette
    public static readonly Color[] CGA =
    {
        Color.FromArgb(0, 0, 0),       // Black
        Color.FromArgb(0, 0, 170),     // Blue
        Color.FromArgb(0, 170, 0),     // Green
        Color.FromArgb(0, 170, 170),   // Cyan
        Color.FromArgb(170, 0, 0),     // Red
        Color.FromArgb(170, 0, 170),   // Magenta
        Color.FromArgb(170, 85, 0),    // Brown
        Color.FromArgb(170, 170, 170), // Light Gray
        Color.FromArgb(85, 85, 85),    // Dark Gray
        Color.FromArgb(85, 85, 255),   // Light Blue
        Color.FromArgb(85, 255, 85),   // Light Green
        Color.FromArgb(85, 255, 255),  // Light Cyan
        Color.FromArgb(255, 85, 85),   // Light Red
        Color.FromArgb(255, 85, 255),  // Light Magenta
        Color.FromArgb(255, 255, 85),  // Yellow
        Color.FromArgb(255, 255, 255)  // White
    };

    // Fire gradient (black -> red -> orange -> yellow -> white)
    public static Color[] GenerateFirePalette()
    {
        var palette = new Color[256];

        for (int i = 0; i < 64; i++)
        {
            palette[i] = Color.FromArgb(i * 4, 0, 0);
        }
        for (int i = 64; i < 128; i++)
        {
            palette[i] = Color.FromArgb(255, (i - 64) * 4, 0);
        }
        for (int i = 128; i < 192; i++)
        {
            palette[i] = Color.FromArgb(255, 255, (i - 128) * 4);
        }
        for (int i = 192; i < 256; i++)
        {
            palette[i] = Color.FromArgb(255, 255, 255);
        }

        return palette;
    }

    // Plasma gradient (cycling colors)
    public static Color[] GeneratePlasmaPalette()
    {
        var palette = new Color[256];

        for (int i = 0; i < 256; i++)
        {
            int r = (int)(128 + 127 * Math.Sin(Math.PI * i / 32));
            int g = (int)(128 + 127 * Math.Sin(Math.PI * i / 64 + 2));
            int b = (int)(128 + 127 * Math.Sin(Math.PI * i / 128 + 4));
            palette[i] = Color.FromArgb(r, g, b);
        }

        return palette;
    }

    // Matrix green gradient
    public static Color[] GenerateMatrixPalette()
    {
        var palette = new Color[256];

        for (int i = 0; i < 256; i++)
        {
            int brightness = i;
            palette[i] = Color.FromArgb(brightness / 4, brightness, brightness / 3);
        }

        return palette;
    }

    // Starfield gradient (dim to bright white with slight blue tint)
    public static Color[] GenerateStarfieldPalette()
    {
        var palette = new Color[256];

        for (int i = 0; i < 256; i++)
        {
            int r = Math.Min(255, i + i / 8);
            int g = Math.Min(255, i + i / 8);
            int b = Math.Min(255, i + i / 4);
            palette[i] = Color.FromArgb(r, g, b);
        }

        return palette;
    }

    // C64 inspired palette
    public static readonly Color[] C64 =
    {
        Color.FromArgb(0, 0, 0),        // Black
        Color.FromArgb(255, 255, 255),  // White
        Color.FromArgb(136, 57, 50),    // Red
        Color.FromArgb(103, 182, 189),  // Cyan
        Color.FromArgb(139, 63, 150),   // Purple
        Color.FromArgb(85, 160, 73),    // Green
        Color.FromArgb(64, 49, 141),    // Blue
        Color.FromArgb(191, 206, 114),  // Yellow
        Color.FromArgb(139, 84, 41),    // Orange
        Color.FromArgb(87, 66, 0),      // Brown
        Color.FromArgb(184, 105, 98),   // Light Red
        Color.FromArgb(80, 80, 80),     // Dark Gray
        Color.FromArgb(120, 120, 120),  // Medium Gray
        Color.FromArgb(148, 224, 137),  // Light Green
        Color.FromArgb(120, 105, 196),  // Light Blue
        Color.FromArgb(159, 159, 159)   // Light Gray
    };

    // Rainbow gradient for sine scroller
    public static Color[] GenerateRainbowPalette()
    {
        var palette = new Color[256];

        for (int i = 0; i < 256; i++)
        {
            float hue = i / 256f;
            palette[i] = HsvToRgb(hue, 1.0f, 1.0f);
        }

        return palette;
    }

    private static Color HsvToRgb(float h, float s, float v)
    {
        int hi = (int)(h * 6) % 6;
        float f = h * 6 - (int)(h * 6);
        float p = v * (1 - s);
        float q = v * (1 - f * s);
        float t = v * (1 - (1 - f) * s);

        float r, g, b;
        switch (hi)
        {
            case 0: r = v; g = t; b = p; break;
            case 1: r = q; g = v; b = p; break;
            case 2: r = p; g = v; b = t; break;
            case 3: r = p; g = q; b = v; break;
            case 4: r = t; g = p; b = v; break;
            default: r = v; g = p; b = q; break;
        }

        return Color.FromArgb((int)(r * 255), (int)(g * 255), (int)(b * 255));
    }
}
