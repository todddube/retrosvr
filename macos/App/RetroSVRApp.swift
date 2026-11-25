//
//  RetroSVRApp.swift
//  RetroSVRApp · RetroSVR
//
//  The standalone Retro 8-Bit app: the saver in a window, or full screen on demand.
//

import AppKit

/// Runs ``RetroSVRView`` outside the system screen saver.
///
/// It opens in a resizable window for trying effects and settings. Full screen (the green
/// button, View ▸ Enter Full Screen, ⌃⌘F, or launching with `--fullscreen`) covers every
/// display like the real saver until Escape or Space is pressed, then returns to the window.
/// The installed `.saver` is unaffected; System Settings still runs it as a normal screen saver.
@main
@MainActor
final class RetroSVRApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: MainWindow?
    private var saverView: RetroSVRView?
    private let fullScreen = FullScreenSaver()
    /// Set when launched with a full-screen argument but not yet active. Since macOS 14
    /// activation is only a request, and until the app is active Esc and Space would go
    /// to whichever app still has the keyboard.
    private var fullScreenWhenActive = false

    /// Launch arguments that start straight in full screen (`/s` mirrors the Windows saver).
    private static let fullScreenArguments: Set<String> = ["--fullscreen", "-fullscreen", "/s"]

    static func main() {
        let app = NSApplication.shared
        let delegate = RetroSVRApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        // NSApplication holds its delegate weakly.
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        guard let view = RetroSVRView(frame: frame, isPreview: false) else { return }
        view.autoresizingMask = [.width, .height]
        view.stopsWithSystemSaver = false

        let window = MainWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Retro 8-Bit"
        window.subtitle = "⌃⌘F full screen  ·  ⌘, settings"
        // Swift owns the window; AppKit's extra release on close would over-release it.
        window.isReleasedWhenClosed = false
        window.collectionBehavior = .fullScreenPrimary
        window.contentMinSize = NSSize(width: 320, height: 200)
        window.contentView = view
        window.delegate = self
        window.onToggleFullScreen = { [weak self] in self?.enterFullScreen() }
        window.setFrameAutosaveName("RetroSVRMainWindow")
        if !window.setFrameUsingName("RetroSVRMainWindow") {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)

        self.window = window
        saverView = view
        fullScreen.onEnd = { [weak self] in self?.fullScreenEnded() }

        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        if CommandLine.arguments.contains(where: Self.fullScreenArguments.contains) {
            if NSApp.isActive {
                enterFullScreen()
            } else {
                fullScreenWhenActive = true
            }
        } else {
            view.startAnimation()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard fullScreenWhenActive else { return }
        fullScreenWhenActive = false
        enterFullScreen()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Tear down the full-screen windows on ⌘Q without restarting the main window's view.
        fullScreen.onEnd = nil
        fullScreen.stop()
    }

    func windowWillClose(_ notification: Notification) {
        saverView?.stopAnimation()
    }

    // MARK: - Full screen

    @objc private func enterFullScreen() {
        guard !fullScreen.isRunning else { return }
        if let window, let sheet = window.attachedSheet {
            window.endSheet(sheet)
        }
        // Only one copy runs at a time, so the window doesn't burn CPU or play sound behind.
        saverView?.stopAnimation()
        fullScreen.start()
    }

    private func fullScreenEnded() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        if window.isVisible, !window.isMiniaturized {
            saverView?.startAnimation()
        }
    }

    func windowDidMiniaturize(_ notification: Notification) {
        saverView?.stopAnimation()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        if !fullScreen.isRunning {
            saverView?.startAnimation()
        }
    }

    // MARK: - Settings

    @objc private func showSettings(_ sender: Any?) {
        guard !fullScreen.isRunning, let window, window.attachedSheet == nil,
              let sheet = saverView?.configureSheet else { return }
        window.makeKeyAndOrderFront(nil)
        window.beginSheet(sheet)
    }

    // MARK: - Menus

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Retro 8-Bit", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Retro 8-Bit", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Retro 8-Bit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let viewMenu = NSMenu(title: "View")
        let fullScreen = viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(enterFullScreen), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        fullScreen.target = self

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = windowMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = appMenu
        mainMenu.addItem(withTitle: "View", action: nil, keyEquivalent: "").submenu = viewMenu
        mainMenu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        return mainMenu
    }
}

/// The app's window. Its full-screen request (green button, fn-F, the system shortcut) runs
/// the saver across every display instead of macOS's own full-screen Space.
private final class MainWindow: NSWindow {
    var onToggleFullScreen: (() -> Void)?

    override func toggleFullScreen(_ sender: Any?) {
        if let onToggleFullScreen {
            onToggleFullScreen()
        } else {
            super.toggleFullScreen(sender)
        }
    }
}
