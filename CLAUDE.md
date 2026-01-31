# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RetroSVR is a Windows 8-bit style screensaver written in C# targeting .NET 9.0. It features classic demoscene effects (starfield, plasma, fire, matrix rain, sine scroller, dissolver) with authentic retro aesthetics through pixel scaling and period-appropriate color palettes.

## Build Commands

```bash
# Build (debug)
dotnet build

# Build release
dotnet publish -c Release -r win-x64 --self-contained false -o publish

# Run in screensaver mode
dotnet run -- /s

# Run settings dialog
dotnet run -- /c

# Install as Windows screensaver (requires admin)
install.bat
```

## Architecture

### Plugin-Based Effect System

All visual effects implement `IEffect` interface (Core/IEffect.cs):
- `Initialize(width, height)` - Setup with buffer dimensions
- `Update(deltaTime)` - Frame-rate-independent animation logic
- `Render(buffer)` - Draw to RenderBuffer
- `Reset()` - Reinitialize state
- Effects are registered in `EffectManager` constructor

### Core Components

- **RenderBuffer** (Core/RenderBuffer.cs): 32-bit ARGB pixel buffer with unsafe pointer access for performance. Handles pixel scaling (default 4x) to achieve chunky 8-bit aesthetic.
- **EffectManager** (Core/EffectManager.cs): Orchestrates effect lifecycle, handles cycling with configurable duration, implements alpha-blending crossfade transitions.
- **RetroPalette** (Core/RetroPalette.cs): Provides color palettes (CGA, C64, dynamic gradients for fire/plasma/matrix).
- **Settings** (Core/Settings.cs): Registry-based persistence at `HKEY_CURRENT_USER\SOFTWARE\Retro8BitScreensaver`.

### Windows Screensaver Integration

Program.cs handles standard screensaver command-line arguments:
- `/s` - Full-screen mode (spawns forms on all monitors)
- `/p [hwnd]` - Preview mode embedded in settings dialog
- `/c` - Configuration dialog

Uses P/Invoke (SetParent, SetWindowLong) for preview window embedding.

## Adding a New Effect

1. Create class in Effects/ implementing `IEffect`
2. Register in `EffectManager` constructor: `_effects.Add(new YourEffect());`
3. Add enum value to `SelectedEffect` in Settings.cs
4. Add to dropdown in SettingsForm.cs

## Key Implementation Details

- **Unsafe code**: RenderBuffer uses unsafe pointers for fast pixel manipulation (project enables AllowUnsafeBlocks)
- **Delta-time animation**: All effects receive deltaTime for frame-rate independence
- **Multi-monitor**: ScreensaverForm spawned on each screen via `Screen.AllScreens`
- **Input handling**: Any keyboard/mouse activity exits screensaver (handled in ScreensaverForm)
