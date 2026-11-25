//
//  RetroSVRView.swift
//  RetroSVR · RetroSVR
//
//  The ScreenSaverView macOS loads: drives the effects and shows them as chunky pixels.
//

import AppKit
import QuartzCore
import RetroSVRCore
import ScreenSaver

/// The saver's principal class. macOS creates one per display (and one for the preview
/// thumbnail in System Settings), so each screen runs its own effects, as on Windows.
///
/// Frames are rendered into a small ``RenderBuffer`` and handed to a layer whose
/// nearest-neighbour magnification turns each buffer pixel into a `pixelScale`-point block.
@objc(RetroSVRView)
final class RetroSVRView: ScreenSaverView {
    private let imageLayer = CALayer()
    private var settings = SaverSettings()
    private var manager: EffectManager?
    private var buffer: RenderBuffer?
    private var lastFrameTime: CFTimeInterval?
    private var configureController: ConfigureSheetController?
    private let desktopImage = DesktopImageSource()

    /// Whether the view stops when the system screen saver is dismissed. On by default for
    /// the `.saver`; the app turns it off, because the real saver ending says nothing about
    /// the app's own window.
    var stopsWithSystemSaver = true

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        imageLayer.magnificationFilter = .nearest
        imageLayer.minificationFilter = .nearest
        // Content changes every frame; implicit animations would smear it.
        imageLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(imageLayer)
        apply(SaverSettings.load(from: SettingsStore.defaults))
    }

    // MARK: - Settings

    /// Rebuilds the effects for `newSettings`; used at start-up and after the sheet's OK.
    func apply(_ newSettings: SaverSettings) {
        settings = newSettings
        animationTimeInterval = 1.0 / Double(settings.frameRate)
        manager?.stop()

        let soundOn = settings.soundEnabled && !isPreview
        let hooks = DissolverEffect.Hooks(
            // The hooks run inside animateOneFrame(), which is always on the main thread.
            sourceImage: { [weak self] width, height in
                MainActor.assumeIsolated { self?.desktopPixels(width: width, height: height) }
            },
            dissolveBegan: soundOn ? { MainActor.assumeIsolated { DissolveSoundPlayer.shared.dissolveBegan() } } : nil,
            dissolveEnded: soundOn ? { MainActor.assumeIsolated { DissolveSoundPlayer.shared.dissolveEnded() } } : nil
        )
        let manager = EffectManager(effects: EffectManager.makeEffects(dissolverHooks: hooks))
        manager.apply(settings)
        self.manager = manager
        rebuildBuffer()
    }

    // MARK: - Geometry

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        if changed { rebuildBuffer() }
    }

    /// Sizes the buffer to cover the view and centres the scaled image, cropping at most one
    /// chunky pixel at the edges rather than leaving black strips.
    private func rebuildBuffer() {
        guard let manager, bounds.width > 0, bounds.height > 0 else { return }
        let scale = CGFloat(settings.pixelScale)
        let width = max(1, Int((bounds.width / scale).rounded(.up)))
        let height = max(1, Int((bounds.height / scale).rounded(.up)))

        buffer = RenderBuffer(width: width, height: height)
        manager.initialize(width: width, height: height)

        let imageSize = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        imageLayer.frame = CGRect(
            x: ((bounds.width - imageSize.width) / 2).rounded(.down),
            y: ((bounds.height - imageSize.height) / 2).rounded(.down),
            width: imageSize.width,
            height: imageSize.height
        )
        imageLayer.contents = nil
    }

    // MARK: - Animation

    override func startAnimation() {
        super.startAnimation()
        lastFrameTime = nil
        if manager == nil {
            apply(settings)
        }
        prefetchDissolverResources()
        if !isPreview, stopsWithSystemSaver {
            // Since macOS 14 the screen saver host often doesn't call stopAnimation() when the
            // saver is dismissed, leaving views animating (and playing sound) in the
            // background. This notification still arrives, so stop on it.
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(screenSaverWillStop(_:)),
                name: Self.willStopNotification,
                object: nil
            )
        }
    }

    override func stopAnimation() {
        super.stopAnimation()
        DistributedNotificationCenter.default().removeObserver(self, name: Self.willStopNotification, object: nil)
        manager?.stop()
        // Since macOS 14 the host keeps old views alive and creates new ones on each
        // activation, so drop the effects' buffers (several MB per display) until restarted.
        manager = nil
        buffer = nil
        imageLayer.contents = nil
    }

    private static let willStopNotification = Notification.Name("com.apple.screensaver.willstop")

    @objc private func screenSaverWillStop(_ notification: Notification) {
        stopAnimation()
    }

    override func animateOneFrame() {
        // The host can deliver a frame after stopAnimation(); drawing it could restart sound.
        guard isAnimating, let manager, let buffer else { return }
        let now = CACurrentMediaTime()
        // Cap the step so a stall (sleep, a slow frame) doesn't make effects jump.
        let deltaTime = min(lastFrameTime.map { now - $0 } ?? 0, 0.1)
        lastFrameTime = now

        manager.update(deltaTime: deltaTime)
        manager.render(into: buffer)
        imageLayer.contents = buffer.makeImage()
    }

    override func draw(_ rect: NSRect) {
        // The layer tree draws everything; skip ScreenSaverView's default fill.
    }

    // MARK: - Configure sheet

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        let controller = ConfigureSheetController(settings: SaverSettings.load(from: SettingsStore.defaults)) { [weak self] newSettings in
            newSettings.save(to: SettingsStore.defaults)
            self?.apply(newSettings)
        }
        configureController = controller
        return controller.window
    }

    // MARK: - Dissolver source

    /// Loads the sound and wallpaper up front, while the saver fades in, rather than as a
    /// hitch when the Dissolver first appears.
    private func prefetchDissolverResources() {
        let usesDissolver = switch settings.selection {
        case .cycleAll, .single(.dissolver): true
        case .single: false
        }
        guard usesDissolver else { return }
        if settings.soundEnabled, !isPreview {
            DissolveSoundPlayer.shared.prepare()
        }
        if let buffer {
            _ = desktopPixels(width: buffer.width, height: buffer.height)
        }
    }

    private func desktopPixels(width: Int, height: Int) -> [UInt32]? {
        guard let screen = window?.screen ?? NSScreen.main else { return nil }
        return desktopImage.pixels(for: screen, width: width, height: height)
    }
}

/// Where the saver's settings live.
enum SettingsStore {
    /// Fixed rather than read from the bundle, so the saver and the app (different bundle IDs)
    /// use the same name. The sandboxed host still keeps its own copy of the values.
    static let moduleName = "com.todddube.RetroSVR"

    /// `ScreenSaverDefaults` is the domain the sandboxed screen saver host can write to.
    static var defaults: UserDefaults {
        ScreenSaverDefaults(forModuleWithName: moduleName) ?? .standard
    }
}
