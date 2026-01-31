# RetroSVR

A Windows screensaver featuring classic 8-bit demoscene effects with authentic retro aesthetics.

## Features

- **Pixel-perfect retro look** - 4x pixel scaling for chunky 8-bit visuals
- **Classic demoscene effects:**
  - Starfield - 3D parallax star animation
  - Plasma - Colorful animated plasma patterns
  - Fire - Realistic flame simulation
  - Matrix Rain - Digital rain effect
  - Sine Scroller - Wavy text animation
  - Dissolver - Dissolve transition effect with crackling sound
- **Period-appropriate palettes** - CGA, C64, and custom gradient palettes
- **Multi-monitor support** - Runs on all connected displays
- **Smooth transitions** - Alpha-blending crossfade between effects
- **Configurable** - Settings dialog for effect selection and cycle duration

## Requirements

- Windows 10/11
- [.NET 9.0 Runtime](https://dotnet.microsoft.com/download/dotnet/9.0)

## Installation

### Option 1: Install as Windows Screensaver

1. Download the latest release or build from source
2. Run `install.bat` as Administrator
3. The screensaver will appear in Windows Screen Saver Settings

### Option 2: Run Standalone

```bash
# Run in screensaver mode
Retro8Bit.exe /s

# Open settings dialog
Retro8Bit.exe /c
```

## Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/retrosvr.git
cd retrosvr

# Build debug
dotnet build

# Build release
dotnet publish -c Release -r win-x64 --self-contained false -o publish

# Run directly
dotnet run -- /s
```

## Configuration

Access settings via:
- Right-click the screensaver in Windows Settings and click "Settings"
- Run with `/c` flag: `Retro8Bit.exe /c`

Options include:
- Effect selection (single effect or cycle through all)
- Cycle duration between effects
- Transition speed

Settings are stored in the Windows Registry at:
`HKEY_CURRENT_USER\SOFTWARE\Retro8BitScreensaver`

## Command Line Arguments

| Argument | Description |
|----------|-------------|
| `/s` | Run in full-screen screensaver mode |
| `/c` | Show configuration dialog |
| `/p [hwnd]` | Preview mode (used by Windows settings) |

## Project Structure

```
RetroScreensaver/
├── Core/
│   ├── IEffect.cs        # Effect interface
│   ├── EffectManager.cs  # Effect lifecycle & transitions
│   ├── RenderBuffer.cs   # Pixel buffer with scaling
│   ├── RetroPalette.cs   # Color palettes
│   └── Settings.cs       # Registry persistence
├── Effects/
│   ├── StarfieldEffect.cs
│   ├── PlasmaEffect.cs
│   ├── FireEffect.cs
│   ├── MatrixRainEffect.cs
│   ├── SineScrollerEffect.cs
│   └── DissolverEffect.cs
├── Forms/
│   ├── ScreensaverForm.cs
│   └── SettingsForm.cs
└── Program.cs
```

## License

MIT License - See LICENSE file for details.
