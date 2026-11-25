# RetroSVR

An 8-bit demoscene screensaver with chunky pixels, period palettes and six classic effects.
It ships as two separate builds from the same repository:

| | **Windows** | **macOS** |
|---|---|---|
| What you get | `Retro8Bit.scr` screensaver (also runs as `Retro8Bit.exe`) | `Retro8Bit.saver` screensaver + `Retro 8-Bit.app` |
| Language | C# / WinForms, .NET 9 | Swift 6 / AppKit |
| Source | [`RetroScreensaver/`](RetroScreensaver/) | [`macos/`](macos/) ([details](macos/README.md)) |
| Requires | Windows 10/11, [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0) | macOS 13+ (Xcode 16+ to build) |
| Builds on | Windows (`dotnet`) | macOS (`xcodebuild`) |
| Install | `install.bat` (as Administrator) | `macos/scripts/install.sh` |
| Settings stored in | Registry: `HKCU\SOFTWARE\Retro8BitScreensaver` | `ScreenSaverDefaults` (`com.todddube.RetroSVR`) |
| Version | 1.0.0 (`RetroScreensaver.csproj`) | 1.0.0 (`macos/project.yml`) |

The two builds share no code. The macOS port was rewritten from the Windows version and fixes
a few of its bugs along the way (see
[Differences from the Windows version](macos/README.md#differences-from-the-windows-version)).

## Effects

Both platforms have the same six:

- **Starfield** – 3D flight through stars
- **Plasma** – interfering sine waves through a cycling palette
- **Fire** – rising demoscene flames
- **Matrix Rain** – green digital rain
- **Sine Scroller** – rainbow text waving over raster bars
- **Dissolver** – a screen capture (Windows) or your wallpaper (macOS) crumbling into falling pixels, with a crackle

Both builds share these features:

- Chunky pixel scaling (4× by default)
- CGA, C64 and gradient palettes
- Runs on every display
- Crossfades between effects
- A settings dialog for effect, cycle duration and more

## Releases

No prebuilt releases are published yet, so build from source for now (below).

When releases are published they'll be tagged per platform, since each build is versioned
separately:

| Tag | Asset | Notes |
|---|---|---|
| `windows-vX.Y.Z` | `Retro8Bit-windows-x64.zip` (`Retro8Bit.scr` + runtime files) | Needs the .NET 9 Desktop Runtime |
| `macos-vX.Y.Z` | `Retro8Bit-macos.zip` (`Retro8Bit.saver` + `Retro 8-Bit.app`, universal arm64/x86_64) | Ad-hoc signed unless notarized; see below |

A macOS download that isn't signed with a Developer ID and notarized is blocked by Gatekeeper.
Right-click › **Open** once, or run `xattr -dr com.apple.quarantine <file>`. Builds you make
yourself on your own Mac aren't affected.

---

## Windows

### Build and install

```bat
:: from the repo root, in an Administrator prompt
install.bat
```

`install.bat` publishes a Release build to `publish\`, copies `Retro8Bit.exe` to
`%WINDIR%\System32\Retro8Bit.scr`, and opens Screen Saver Settings. Choose **Retro8Bit**.

To build without installing:

```bash
dotnet build                                                                    # debug
dotnet publish -c Release -r win-x64 --self-contained false -o publish          # release
```

### Run

| Command | What it does |
|---|---|
| `Retro8Bit.exe /s` (or `run.bat`) | Full screen on every display; any key or mouse movement exits |
| `Retro8Bit.exe /c` | Settings dialog (also the **Settings** button in Screen Saver Settings) |
| `Retro8Bit.exe /p <hwnd>` | Preview inside Windows' settings dialog (used by Windows) |

### Project layout

```
RetroScreensaver/
├── Core/       IEffect, EffectManager (cycling + crossfade), RenderBuffer, RetroPalette, Settings, SoundHelper
├── Effects/    the six effects
├── Forms/      ScreensaverForm, SettingsForm
└── Program.cs  /s /c /p argument handling
```

---

## macOS

### Build and install

```bash
cd macos
scripts/install.sh               # saver → ~/Library/Screen Savers, app → ~/Applications
scripts/install.sh --uninstall   # remove both
```

Then choose **Retro 8-Bit** in System Settings › Screen Saver.

### Two ways to run it

- **As a screensaver.** System Settings runs it full screen on every display. Any key or mouse
  movement ends it, as usual. **Options…** opens the settings sheet.
- **As an app.** **Retro 8-Bit.app** opens the saver in a window for trying effects (⌘, for
  settings).
  - **Go full screen** with ⌃⌘F, the green window button, or
    `open "$HOME/Applications/Retro 8-Bit.app" --args --fullscreen`. It covers every display
    and shows a **[ESC] or [SPACE] to exit** banner.
  - **Leave full screen** with **Esc** or **Space**, which return to the window.

The app and the installed saver keep separate settings, because macOS runs screensavers in a
sandboxed host with its own preferences.

### Develop

```bash
cd macos/RetroSVRCore && swift test      # engine tests
cd macos && open RetroSVR.xcodeproj      # schemes: RetroSVR (.saver), RetroSVRApp (app)
```

`RetroSVR.xcodeproj` is generated from `macos/project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). See [`macos/README.md`](macos/README.md)
for the layout, settings, signing and notarization.

---

## Get the source

```bash
git clone https://github.com/todddube/retrosvr.git
```

## License

MIT.
