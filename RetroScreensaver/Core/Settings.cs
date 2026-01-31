using Microsoft.Win32;

namespace RetroScreensaver.Core;

public enum EffectType
{
    Starfield,
    Plasma,
    Fire,
    MatrixRain,
    SineScroller,
    Dissolver,
    All
}

public static class Settings
{
    private const string RegistryKey = @"SOFTWARE\Retro8BitScreensaver";

    public static EffectType CurrentEffect { get; set; } = EffectType.All;
    public static int EffectDuration { get; set; } = 30; // seconds per effect
    public static int PixelScale { get; set; } = 4; // Scale factor for 8-bit look
    public static int FrameRate { get; set; } = 30;
    public static bool SmoothTransitions { get; set; } = true;

    public static void Load()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RegistryKey);
            if (key != null)
            {
                CurrentEffect = (EffectType)(int)(key.GetValue("Effect", (int)EffectType.All) ?? 0);
                EffectDuration = (int)(key.GetValue("EffectDuration", 30) ?? 30);
                PixelScale = (int)(key.GetValue("PixelScale", 4) ?? 4);
                FrameRate = (int)(key.GetValue("FrameRate", 30) ?? 30);
                SmoothTransitions = ((int)(key.GetValue("SmoothTransitions", 1) ?? 1)) == 1;
            }
        }
        catch
        {
            // Use defaults on error
        }
    }

    public static void Save()
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RegistryKey);
            key?.SetValue("Effect", (int)CurrentEffect);
            key?.SetValue("EffectDuration", EffectDuration);
            key?.SetValue("PixelScale", PixelScale);
            key?.SetValue("FrameRate", FrameRate);
            key?.SetValue("SmoothTransitions", SmoothTransitions ? 1 : 0);
        }
        catch
        {
            // Silently fail
        }
    }
}
