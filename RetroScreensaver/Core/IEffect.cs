namespace RetroScreensaver.Core;

/// <summary>
/// Interface for all screensaver effects.
/// </summary>
public interface IEffect : IDisposable
{
    string Name { get; }
    void Initialize(int width, int height);
    void Update(double deltaTime);
    void Render(RenderBuffer buffer);
    void Reset();
}
