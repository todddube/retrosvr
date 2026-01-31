using RetroScreensaver.Effects;

namespace RetroScreensaver.Core;

/// <summary>
/// Manages effect lifecycle, transitions, and cycling.
/// </summary>
public sealed class EffectManager : IDisposable
{
    private readonly List<IEffect> _effects =
    [
        new StarfieldEffect(),
        new PlasmaEffect(),
        new FireEffect(),
        new MatrixRainEffect(),
        new SineScrollerEffect(),
        new DissolverEffect()
    ];
    private int _currentEffectIndex;
    private double _effectTimer;
    private double _transitionAlpha;
    private bool _inTransition;
    private int _nextEffectIndex;
    private RenderBuffer? _transitionBuffer;
    private bool _disposed;

    public IEffect? CurrentEffect => _currentEffectIndex < _effects.Count ? _effects[_currentEffectIndex] : null;
    public bool SmoothTransitions { get; set; } = true;
    public double EffectDuration { get; set; } = 30.0;

    public void Initialize(int width, int height, EffectType startEffect = EffectType.All)
    {
        foreach (var effect in _effects)
        {
            effect.Initialize(width, height);
        }

        if (SmoothTransitions)
        {
            _transitionBuffer = new RenderBuffer(width / Settings.PixelScale, height / Settings.PixelScale, Settings.PixelScale);
        }

        // Set starting effect
        if (startEffect != EffectType.All)
        {
            _currentEffectIndex = (int)startEffect;
            if (_currentEffectIndex >= _effects.Count)
                _currentEffectIndex = 0;
        }
        else
        {
            _currentEffectIndex = 0;
        }

        _effectTimer = 0;
        _inTransition = false;
    }

    public void Update(double deltaTime)
    {
        if (_disposed || _effects.Count == 0) return;

        // Update current effect
        CurrentEffect?.Update(deltaTime);

        // Handle cycling between effects (only in "All" mode)
        if (Settings.CurrentEffect == EffectType.All)
        {
            _effectTimer += deltaTime;

            if (_inTransition)
            {
                // Update transition
                _transitionAlpha += deltaTime * 2; // 0.5 second transition

                if (_transitionAlpha >= 1.0)
                {
                    // Transition complete
                    _inTransition = false;
                    _currentEffectIndex = _nextEffectIndex;
                    _effectTimer = 0;
                }
                else
                {
                    // Update next effect during transition
                    _effects[_nextEffectIndex].Update(deltaTime);
                }
            }
            else if (_effectTimer >= EffectDuration)
            {
                // Start transition to next effect
                StartTransition();
            }
        }
    }

    private void StartTransition()
    {
        if (!SmoothTransitions)
        {
            // Instant switch
            _currentEffectIndex = (_currentEffectIndex + 1) % _effects.Count;
            _effects[_currentEffectIndex].Reset();
            _effectTimer = 0;
        }
        else
        {
            // Start smooth transition
            _inTransition = true;
            _transitionAlpha = 0;
            _nextEffectIndex = (_currentEffectIndex + 1) % _effects.Count;
            _effects[_nextEffectIndex].Reset();
        }
    }

    public void Render(RenderBuffer buffer)
    {
        if (_disposed || _effects.Count == 0) return;

        if (_inTransition && SmoothTransitions && _transitionBuffer != null)
        {
            // Render both effects and blend
            CurrentEffect?.Render(buffer);
            _effects[_nextEffectIndex].Render(_transitionBuffer);

            // Crossfade blend
            BlendBuffers(buffer, _transitionBuffer, _transitionAlpha);
        }
        else
        {
            CurrentEffect?.Render(buffer);
        }
    }

    private void BlendBuffers(RenderBuffer dest, RenderBuffer src, double alpha)
    {
        int a = (int)(alpha * 255);
        int invA = 255 - a;

        for (int y = 0; y < dest.Height; y++)
        {
            for (int x = 0; x < dest.Width; x++)
            {
                int destPixel = dest.GetPixel(x, y);
                int srcPixel = src.GetPixel(x, y);

                int dr = (destPixel >> 16) & 0xFF;
                int dg = (destPixel >> 8) & 0xFF;
                int db = destPixel & 0xFF;

                int sr = (srcPixel >> 16) & 0xFF;
                int sg = (srcPixel >> 8) & 0xFF;
                int sb = srcPixel & 0xFF;

                int r = (dr * invA + sr * a) / 255;
                int g = (dg * invA + sg * a) / 255;
                int b = (db * invA + sb * a) / 255;

                dest.SetPixel(x, y, unchecked((int)(0xFF000000u | ((uint)r << 16) | ((uint)g << 8) | (uint)b)));
            }
        }
    }

    public void SetEffect(EffectType effect)
    {
        if (effect == EffectType.All)
        {
            _currentEffectIndex = 0;
        }
        else
        {
            int index = (int)effect;
            if (index < _effects.Count)
            {
                _currentEffectIndex = index;
            }
        }
        _effects[_currentEffectIndex].Reset();
        _effectTimer = 0;
        _inTransition = false;
    }

    public IReadOnlyList<IEffect> GetEffects() => _effects;

    public void Dispose()
    {
        if (!_disposed)
        {
            foreach (var effect in _effects)
            {
                effect.Dispose();
            }
            _effects.Clear();
            _transitionBuffer?.Dispose();
            _disposed = true;
        }
    }
}
