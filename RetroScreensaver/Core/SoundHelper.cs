using System.Media;

namespace RetroScreensaver.Core;

/// <summary>
/// Generates and plays simple retro-style sound effects.
/// </summary>
public static class SoundHelper
{
    private static SoundPlayer? _dissolvePlayer;
    private static bool _isInitialized;

    /// <summary>
    /// Plays a light dissolving/crackling sound effect.
    /// </summary>
    public static void PlayDissolveSound()
    {
        try
        {
            if (!_isInitialized)
            {
                InitializeDissolveSound();
                _isInitialized = true;
            }

            _dissolvePlayer?.Play();
        }
        catch
        {
            // Silently fail if audio isn't available
        }
    }

    /// <summary>
    /// Stops the dissolve sound if playing.
    /// </summary>
    public static void StopDissolveSound()
    {
        try
        {
            _dissolvePlayer?.Stop();
        }
        catch
        {
            // Silently fail
        }
    }

    private static void InitializeDissolveSound()
    {
        // Generate a dissolving/crackling sound that builds up and fades
        // WAV format: 8-bit mono, 22050 Hz sample rate
        const int sampleRate = 22050;
        const double duration = 28.0; // Match dissolve cycle (~5.0 progress / 0.15 speed ≈ 33s, but particles fall by ~28s)
        int numSamples = (int)(sampleRate * duration);

        var random = new Random(42); // Fixed seed for consistent sound

        // Create WAV data in memory
        using var stream = new MemoryStream();
        using var writer = new BinaryWriter(stream);

        // WAV header
        writer.Write("RIFF"u8);
        writer.Write(36 + numSamples); // File size - 8
        writer.Write("WAVE"u8);

        // Format chunk
        writer.Write("fmt "u8);
        writer.Write(16); // Chunk size
        writer.Write((short)1); // PCM format
        writer.Write((short)1); // Mono
        writer.Write(sampleRate); // Sample rate
        writer.Write(sampleRate); // Byte rate (sample rate * channels * bits/8)
        writer.Write((short)1); // Block align
        writer.Write((short)8); // Bits per sample

        // Data chunk
        writer.Write("data"u8);
        writer.Write(numSamples);

        // Generate dissolving sound that builds up and fades
        for (int i = 0; i < numSamples; i++)
        {
            double t = (double)i / sampleRate;
            double progress = t / duration;

            // Envelope: start very quiet, build to peak at 65%, then fade out
            double envelope;
            if (progress < 0.15)
            {
                // Very slow, quiet start (first 15%)
                envelope = (progress / 0.15) * 0.2; // Max 0.2 at 15%
            }
            else if (progress < 0.65)
            {
                // Build up to peak (15% to 65%)
                double buildProgress = (progress - 0.15) / 0.5;
                envelope = 0.2 + buildProgress * 0.8; // 0.2 -> 1.0
            }
            else
            {
                // Fade out (65% to 100%)
                double fadeProgress = (progress - 0.65) / 0.35;
                envelope = 1.0 - fadeProgress; // 1.0 -> 0.0
            }

            // Crackle density increases with envelope
            double crackleChance = 0.01 + envelope * 0.04; // 1% to 5%
            double loudCrackleChance = 0.002 + envelope * 0.008; // 0.2% to 1%

            // Mix of soft noise and crackles - intensity scales with envelope
            double sample = 0;

            // Base soft noise (scales with envelope)
            double noiseLevel = 0.05 + envelope * 0.15; // 0.05 to 0.20
            sample += (random.NextDouble() - 0.5) * noiseLevel;

            // Crackles (frequency and intensity scale with progress)
            if (random.NextDouble() < crackleChance)
            {
                double crackleIntensity = 0.2 + envelope * 0.3;
                sample += (random.NextDouble() - 0.5) * crackleIntensity;
            }

            // Louder crackles at peak
            if (random.NextDouble() < loudCrackleChance)
            {
                double loudIntensity = 0.3 + envelope * 0.4;
                sample += (random.NextDouble() - 0.5) * loudIntensity;
            }

            // Apply envelope and keep overall volume light
            sample *= envelope * 0.45;

            // Convert to 8-bit unsigned
            int byteValue = (int)((sample + 0.5) * 255);
            byteValue = Math.Clamp(byteValue, 0, 255);

            writer.Write((byte)byteValue);
        }

        writer.Flush();
        stream.Position = 0;

        // Create player from stream (need to copy since SoundPlayer takes ownership)
        var soundStream = new MemoryStream(stream.ToArray());
        _dissolvePlayer = new SoundPlayer(soundStream);
        _dissolvePlayer.Load();
    }

    /// <summary>
    /// Releases audio resources.
    /// </summary>
    public static void Dispose()
    {
        _dissolvePlayer?.Dispose();
        _dissolvePlayer = null;
        _isInitialized = false;
    }
}
