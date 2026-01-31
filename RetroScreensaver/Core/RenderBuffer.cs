using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace RetroScreensaver.Core;

/// <summary>
/// Fast pixel buffer for 8-bit style rendering with scaling.
/// Uses direct memory access for performance.
/// </summary>
public sealed class RenderBuffer : IDisposable
{
    private readonly int _width;
    private readonly int _height;
    private readonly int _scale;
    private readonly int[] _pixels;
    private Bitmap? _bitmap;
    private BitmapData? _bitmapData;
    private bool _disposed;

    public int Width => _width;
    public int Height => _height;
    public int Scale => _scale;
    public int ScaledWidth => _width * _scale;
    public int ScaledHeight => _height * _scale;

    public RenderBuffer(int width, int height, int scale = 4)
    {
        _width = width;
        _height = height;
        _scale = scale;
        _pixels = new int[_width * _height];
        _bitmap = new Bitmap(_width * _scale, _height * _scale, PixelFormat.Format32bppArgb);
    }

    public void SetPixel(int x, int y, Color color)
    {
        if (x >= 0 && x < _width && y >= 0 && y < _height)
        {
            _pixels[y * _width + x] = color.ToArgb();
        }
    }

    public void SetPixel(int x, int y, int argb)
    {
        if (x >= 0 && x < _width && y >= 0 && y < _height)
        {
            _pixels[y * _width + x] = argb;
        }
    }

    public int GetPixel(int x, int y)
    {
        if (x >= 0 && x < _width && y >= 0 && y < _height)
        {
            return _pixels[y * _width + x];
        }
        return 0;
    }

    public void Clear()
    {
        Array.Clear(_pixels, 0, _pixels.Length);
    }

    public void Clear(Color color)
    {
        int argb = color.ToArgb();
        for (int i = 0; i < _pixels.Length; i++)
        {
            _pixels[i] = argb;
        }
    }

    public void Fill(int[] sourcePixels)
    {
        int length = Math.Min(sourcePixels.Length, _pixels.Length);
        Array.Copy(sourcePixels, _pixels, length);
    }

    /// <summary>
    /// Draws the buffer to the graphics context with scaling for chunky 8-bit pixels.
    /// </summary>
    public void DrawTo(Graphics g)
    {
        if (_bitmap == null || _disposed) return;

        // Lock bitmap for fast pixel access
        var rect = new Rectangle(0, 0, _bitmap.Width, _bitmap.Height);
        _bitmapData = _bitmap.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);

        try
        {
            unsafe
            {
                int* dest = (int*)_bitmapData.Scan0;
                int stride = _bitmapData.Stride / 4;

                // Scale up pixels for chunky 8-bit look
                for (int y = 0; y < _height; y++)
                {
                    for (int x = 0; x < _width; x++)
                    {
                        int pixel = _pixels[y * _width + x];

                        // Fill the scaled block
                        for (int sy = 0; sy < _scale; sy++)
                        {
                            int destY = (y * _scale + sy) * stride;
                            for (int sx = 0; sx < _scale; sx++)
                            {
                                dest[destY + (x * _scale + sx)] = pixel;
                            }
                        }
                    }
                }
            }
        }
        finally
        {
            _bitmap.UnlockBits(_bitmapData);
        }

        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
        g.DrawImage(_bitmap, 0, 0);
    }

    /// <summary>
    /// Fast horizontal line drawing.
    /// </summary>
    public void DrawHLine(int x1, int x2, int y, int argb)
    {
        if (y < 0 || y >= _height) return;
        if (x1 > x2) (x1, x2) = (x2, x1);
        x1 = Math.Max(0, x1);
        x2 = Math.Min(_width - 1, x2);

        int offset = y * _width;
        for (int x = x1; x <= x2; x++)
        {
            _pixels[offset + x] = argb;
        }
    }

    /// <summary>
    /// Fast vertical line drawing.
    /// </summary>
    public void DrawVLine(int x, int y1, int y2, int argb)
    {
        if (x < 0 || x >= _width) return;
        if (y1 > y2) (y1, y2) = (y2, y1);
        y1 = Math.Max(0, y1);
        y2 = Math.Min(_height - 1, y2);

        for (int y = y1; y <= y2; y++)
        {
            _pixels[y * _width + x] = argb;
        }
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            _bitmap?.Dispose();
            _bitmap = null;
            _disposed = true;
        }
    }
}
