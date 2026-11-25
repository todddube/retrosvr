# RetroSVR for macOS

A native Swift port of the Windows Retro 8-Bit screensaver: the same six demoscene effects,
built as a `.saver` bundle for System Settings › Screen Saver, plus a **Retro 8-Bit** app
that runs them in a window or full screen without installing anything.

| Effect | What it does |
|---|---|
| Starfield | 3D flight through stars with pulsing warp speed and trails |
| Plasma | Five interfering sine waves through a cycling palette |
| Fire | Rising demoscene fire with flame tongues |
| Matrix Rain | Green digital rain with bright heads and glitch pixels |
| Sine Scroller | Rainbow text waving across raster bars |
| Dissolver | Your wallpaper, pixelated, crumbling into falling particles with a crackle |

## Requirements

- macOS 13 or later
- Xcode 16 or later (Swift 6) to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) only if you change `project.yml`

## Install

```bash
cd macos
scripts/install.sh               # build Release; saver → ~/Library/Screen Savers, app → ~/Applications
scripts/install.sh --uninstall   # remove both
```

Then pick **Retro 8-Bit** in System Settings › Screen Saver. **Options…** opens the settings sheet.
There it behaves like any screen saver: full screen on every display, ended by any key or mouse movement.

## The Retro 8-Bit app

Launching **Retro 8-Bit.app** opens the saver in a resizable window, which is handy for trying
effects and settings.

| Action | How |
|---|---|
| Settings | ⌘, (the same sheet as System Settings' **Options…**) |
| Full screen | ⌃⌘F, View › Enter Full Screen, the green window button, or launch with `--fullscreen` |
| Leave full screen | **Esc** or **Space** |

Full screen covers every display, hides the Dock, menu bar and cursor, and shows a
**[ESC] or [SPACE] to exit** banner. The banner fades after a few seconds and comes back when
you move the mouse or press another key. Unlike the system saver, moving the mouse doesn't end it.
Switching to another app (⌘Tab) also ends it, and ⌘Q quits.

```bash
open "$HOME/Applications/Retro 8-Bit.app" --args --fullscreen
```

The app's settings are separate from the installed saver's. The saver runs inside Apple's
sandboxed host, which keeps its own copy of the preferences.

## Settings

| Setting | Range | Default |
|---|---|---|
| Effect | All Effects (Cycle) or one effect | All |
| Effect duration | 5–120 s (cycling only) | 30 s |
| Pixel scale | 1–8× (screen points per chunky pixel) | 4× |
| Frame rate | 15–60 FPS | 30 |
| Smooth transitions | 0.5 s crossfade instead of a cut (cycling only) | On |
| Dissolver sound | Crackle during the Dissolver | On |

Settings are stored with `ScreenSaverDefaults` under the module name `com.todddube.RetroSVR`.

## Develop

```bash
cd macos
open RetroSVR.xcodeproj                  # schemes: RetroSVR (the .saver), RetroSVRApp (the app)
cd RetroSVRCore && swift test            # engine tests, no Xcode project needed
RETROSVR_SNAPSHOT_DIR=/tmp/shots swift test --filter snapshot   # PNG of every effect
```

Run the **RetroSVRApp** scheme to try a change in the app, either windowed or full screen.
You don't need to install the saver or restart the system screen saver host.

`RetroSVR.xcodeproj` is generated from `project.yml`. Edit the spec and run `xcodegen generate`
rather than changing the project in Xcode.

### Layout

```
macos/
├── project.yml                 XcodeGen spec (bundle ids, signing, targets)
├── RetroSVRCore/               Swift package: the platform-neutral engine
│   ├── Sources/RetroSVRCore/
│   │   ├── Effect.swift            Effect protocol, EffectKind, EffectSelection
│   │   ├── EffectManager.swift     cycling and crossfades
│   │   ├── RenderBuffer.swift      chunky-pixel buffer → CGImage
│   │   ├── RetroPalette.swift      CGA, C64 and effect gradients
│   │   ├── SaverSettings.swift     options and persistence
│   │   ├── DissolveSound.swift     crackle WAV synthesis
│   │   ├── FastRandom.swift        seedable per-pixel RNG
│   │   └── Effects/                the six effects
│   └── Tests/RetroSVRCoreTests/
├── Saver/                      the .saver bundle (AppKit)
│   ├── RetroSVRView.swift          ScreenSaverView subclass (principal class)
│   ├── ConfigureSheetController.swift
│   ├── RetroStyle.swift            shared green-on-charcoal colours and fonts
│   ├── DissolveSoundPlayer.swift
│   └── DesktopImageSource.swift
├── App/                        Retro 8-Bit.app (also compiles Saver/)
│   ├── RetroSVRApp.swift           window, menus, launch arguments
│   ├── FullScreenSaver.swift       per-display full-screen windows, Esc/Space to exit
│   └── ExitHintView.swift          the keycap banner
└── scripts/install.sh
```

### Adding an effect

1. Add a class in `RetroSVRCore/Sources/RetroSVRCore/Effects/` that conforms to `Effect`.
2. Add a case to `EffectKind` (its position sets the cycling order) and a `displayName`.
3. Return it from `EffectManager.makeEffects`.

The settings popup and the tests that iterate over `EffectKind.allCases` pick it up automatically.

## Differences from the Windows version

- **Effects run at the buffer's real size.** Windows sized effects to the whole window but
  drew into a buffer ¼ of that size. Only the top-left quarter of each effect showed, and
  each frame did 16× the work. As a result, the starfield and plasma are now centred, and
  every Matrix column is visible.
- **Fire was re-tuned.** The Windows fire multiplied heat by 1.25× each step. At the
  correct size, that fills the screen with white within seconds. It now uses height-scaled
  cooling from a scrolling noise map (the classic demoscene technique), which produces
  flame tongues.
- **Frame-rate independent.** Fire runs on a fixed 30 Hz step. Starfield warp and
  Dissolver drag are per second rather than per frame. Changing FPS changes smoothness,
  not speed.
- **Dissolver source.** Windows' "screen capture" captured the saver's own black window.
  A macOS screen saver can't get Screen Recording permission, so the Dissolver uses your
  wallpaper. If the wallpaper can't be read (dynamic or video wallpapers, sandbox limits),
  it uses its built-in rainbow pattern.
- **Sound.** One crackle plays even with several displays, never in the System Settings
  thumbnail, and it stops when the cycle moves on. There's a setting to turn it off.
- **No Preview button.** System Settings shows a live preview, and the Retro 8-Bit app
  runs it in a window.
- Multi-monitor support, input-to-exit and the preview thumbnail are handled by macOS itself.

## Distribution

Local builds are ad-hoc signed, which is enough to run on the Mac that built them. To share
the `.saver`, set `DEVELOPMENT_TEAM` and a Developer ID identity in `project.yml`, then
notarize the bundle (`xcrun notarytool submit … --wait`, then `xcrun stapler staple`).
`scripts/install.sh` builds with a generic destination, so the binary is universal (arm64 + x86_64).

GitHub releases of the macOS build are tagged `macos-vX.Y.Z`, separately from the Windows
build's `windows-vX.Y.Z`. Each release has one zip, `Retro8Bit-macos.zip`, containing
`Retro8Bit.saver` and `Retro 8-Bit.app`.
