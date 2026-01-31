using System.Diagnostics;
using RetroScreensaver.Core;

namespace RetroScreensaver.Forms;

/// <summary>
/// Main screensaver form - renders the effects full screen.
/// </summary>
public class ScreensaverForm : Form
{
    private readonly bool _isPreview;
    private readonly EffectManager _effectManager;
    private RenderBuffer? _renderBuffer;
    private readonly System.Windows.Forms.Timer _renderTimer;
    private readonly Stopwatch _stopwatch;
    private double _lastTime;
    private Point _lastMousePos;
    private bool _mouseInitialized;
    private BufferedGraphicsContext? _graphicsContext;
    private BufferedGraphics? _bufferedGraphics;

    public ScreensaverForm(bool isPreview)
    {
        _isPreview = isPreview;
        _effectManager = new EffectManager();
        _stopwatch = new Stopwatch();
        _renderTimer = new System.Windows.Forms.Timer();

        InitializeForm();
    }

    private void InitializeForm()
    {
        // Load settings
        Settings.Load();

        // Form setup
        Text = "Retro 8-Bit Screensaver";
        FormBorderStyle = FormBorderStyle.None;
        BackColor = Color.Black;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false;
        DoubleBuffered = true;

        if (!_isPreview)
        {
            // Full screen mode
            WindowState = FormWindowState.Maximized;
            TopMost = true;
            Cursor.Hide();
        }

        // Timer for rendering
        int targetFps = Settings.FrameRate;
        _renderTimer.Interval = 1000 / targetFps;
        _renderTimer.Tick += OnRenderTick;

        // Event handlers
        Load += OnFormLoad;
        FormClosing += OnFormClosing;
        KeyDown += OnKeyDown;
        MouseMove += OnMouseMove;
        MouseDown += OnMouseDown;
        MouseClick += OnMouseClick;
        Resize += OnFormResize;
    }

    private void OnFormLoad(object? sender, EventArgs e)
    {
        InitializeRendering();
        _stopwatch.Start();
        _renderTimer.Start();
    }

    private void InitializeRendering()
    {
        int scale = Settings.PixelScale;
        int bufferWidth = Math.Max(1, ClientSize.Width / scale);
        int bufferHeight = Math.Max(1, ClientSize.Height / scale);

        _renderBuffer?.Dispose();
        _renderBuffer = new RenderBuffer(bufferWidth, bufferHeight, scale);

        _effectManager.SmoothTransitions = Settings.SmoothTransitions;
        _effectManager.EffectDuration = Settings.EffectDuration;
        _effectManager.Initialize(ClientSize.Width, ClientSize.Height, Settings.CurrentEffect);

        // Setup buffered graphics for smooth rendering
        _graphicsContext = BufferedGraphicsManager.Current;
        _graphicsContext.MaximumBuffer = new Size(ClientSize.Width + 1, ClientSize.Height + 1);

        _bufferedGraphics?.Dispose();
        _bufferedGraphics = _graphicsContext.Allocate(CreateGraphics(), ClientRectangle);
    }

    private void OnFormResize(object? sender, EventArgs e)
    {
        if (ClientSize.Width > 0 && ClientSize.Height > 0)
        {
            InitializeRendering();
        }
    }

    private void OnRenderTick(object? sender, EventArgs e)
    {
        // Calculate delta time
        double currentTime = _stopwatch.Elapsed.TotalSeconds;
        double deltaTime = currentTime - _lastTime;
        _lastTime = currentTime;

        // Cap delta time to prevent huge jumps
        deltaTime = Math.Min(deltaTime, 0.1);

        // Update effects
        _effectManager.Update(deltaTime);

        // Render
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (_renderBuffer == null || _bufferedGraphics == null) return;

        // Render effect to buffer
        _effectManager.Render(_renderBuffer);

        // Draw buffer to screen
        Graphics g = _bufferedGraphics.Graphics;
        g.Clear(Color.Black);
        _renderBuffer.DrawTo(g);

        // Flip buffers
        _bufferedGraphics.Render(e.Graphics);
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        // Prevent background painting to avoid flicker
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (!_isPreview)
        {
            ExitScreensaver();
        }
    }

    private void OnMouseMove(object? sender, MouseEventArgs e)
    {
        if (_isPreview) return;

        if (!_mouseInitialized)
        {
            _lastMousePos = e.Location;
            _mouseInitialized = true;
            return;
        }

        // Exit if mouse moved significantly
        int dx = Math.Abs(e.X - _lastMousePos.X);
        int dy = Math.Abs(e.Y - _lastMousePos.Y);

        if (dx > 10 || dy > 10)
        {
            ExitScreensaver();
        }
    }

    private void OnMouseDown(object? sender, MouseEventArgs e)
    {
        if (_isPreview)
        {
            Close();
        }
        else
        {
            ExitScreensaver();
        }
    }

    private void OnMouseClick(object? sender, MouseEventArgs e)
    {
        if (!_isPreview)
        {
            ExitScreensaver();
        }
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        _renderTimer.Stop();
        _stopwatch.Stop();
    }

    private void ExitScreensaver()
    {
        _renderTimer.Stop();
        Cursor.Show();
        Application.Exit();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _renderTimer.Dispose();
            _renderBuffer?.Dispose();
            _effectManager.Dispose();
            _bufferedGraphics?.Dispose();
        }
        base.Dispose(disposing);
    }
}
