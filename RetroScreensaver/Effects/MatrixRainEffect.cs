using RetroScreensaver.Core;

namespace RetroScreensaver.Effects;

/// <summary>
/// Matrix-style digital rain effect with 8-bit character aesthetic.
/// Falling columns of characters with glowing heads.
/// </summary>
public sealed class MatrixRainEffect : IEffect
{
    private struct Column
    {
        public double Y;
        public double Speed;
        public int Length;
        public int[] Characters;
        public double CharChangeTimer;
    }

    public string Name => "Matrix Rain";

    private int _width;
    private int _height;
    private Column[] _columns = Array.Empty<Column>();
    private readonly Random _random = new();
    private Color[] _palette = Array.Empty<Color>();

    // 8-bit style "characters" - we'll represent them as brightness patterns
    private static readonly int[] CharPatterns = { 0xDB, 0xB2, 0xB1, 0xB0, 0x23, 0x58, 0x2A, 0x25, 0x40, 0x26 };

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _palette = RetroPalette.GenerateMatrixPalette();

        // One column per horizontal pixel
        _columns = new Column[_width];

        for (int i = 0; i < _width; i++)
        {
            InitColumn(ref _columns[i]);
            // Stagger initial positions for variety
            _columns[i].Y = -_random.Next(0, _height);
        }
    }

    private void InitColumn(ref Column col)
    {
        col.Speed = 5 + _random.NextDouble() * 15;
        col.Length = _random.Next(5, Math.Max(6, _height / 3));
        col.Y = -col.Length;
        col.Characters = new int[col.Length];
        col.CharChangeTimer = 0;

        for (int i = 0; i < col.Length; i++)
        {
            col.Characters[i] = CharPatterns[_random.Next(CharPatterns.Length)];
        }
    }

    public void Update(double deltaTime)
    {
        for (int i = 0; i < _columns.Length; i++)
        {
            ref Column col = ref _columns[i];

            // Move column down
            col.Y += col.Speed * deltaTime;

            // Random character changes for flickering effect
            col.CharChangeTimer += deltaTime;
            if (col.CharChangeTimer > 0.1)
            {
                col.CharChangeTimer = 0;
                // Change a random character in the column
                if (col.Characters.Length > 0)
                {
                    int idx = _random.Next(col.Characters.Length);
                    col.Characters[idx] = CharPatterns[_random.Next(CharPatterns.Length)];
                }
            }

            // Reset column when fully off screen
            if (col.Y - col.Length > _height)
            {
                InitColumn(ref col);
            }
        }
    }

    public void Render(RenderBuffer buffer)
    {
        buffer.Clear();

        for (int x = 0; x < _columns.Length; x++)
        {
            ref Column col = ref _columns[x];

            for (int i = 0; i < col.Length; i++)
            {
                int y = (int)col.Y - i;

                if (y < 0 || y >= _height) continue;

                // Calculate brightness - head is brightest, fades toward tail
                int brightness;
                if (i == 0)
                {
                    // Bright white head
                    brightness = 255;
                    buffer.SetPixel(x, y, Color.FromArgb(200, 255, 200));
                }
                else
                {
                    // Fading green tail
                    float fade = 1.0f - (float)i / col.Length;
                    brightness = (int)(fade * 200);
                    buffer.SetPixel(x, y, _palette[Math.Clamp(brightness, 0, 255)]);
                }
            }
        }

        // Add some random "glitch" pixels for atmosphere
        for (int i = 0; i < _width / 20; i++)
        {
            int gx = _random.Next(_width);
            int gy = _random.Next(_height);
            if (_random.NextDouble() < 0.5)
            {
                buffer.SetPixel(gx, gy, _palette[_random.Next(50, 150)]);
            }
        }
    }

    public void Reset()
    {
        for (int i = 0; i < _columns.Length; i++)
        {
            InitColumn(ref _columns[i]);
            _columns[i].Y = -_random.Next(0, _height);
        }
    }

    public void Dispose() { }
}
