//
//  FullScreenSaver.swift
//  RetroSVRApp · RetroSVR
//
//  Runs the saver full screen on every display from the app, until Escape or Space.
//

import AppKit

/// Covers every display with a borderless window running its own ``RetroSVRView``, the way
/// the system screen saver does, with the Dock, menu bar and cursor hidden.
///
/// Unlike the system saver, a stray mouse nudge doesn't end it: only Escape or Space do, and
/// an ``ExitHintView`` says so. The hint shows on start and whenever the mouse moves or
/// another key is pressed, then fades. Switching to another app also ends it, so the
/// covering windows can't be left stranded over someone else's work.
@MainActor
final class FullScreenSaver {
    /// Called after the saver has ended and its windows are gone.
    var onEnd: (() -> Void)?

    /// Whether the covering windows are up.
    var isRunning: Bool { !windows.isEmpty }

    private var windows: [NSWindow] = []
    private var views: [RetroSVRView] = []
    private var hints: [ExitHintView] = []
    private var eventMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    /// Fades the hint out; replaced each time the hint is shown again.
    private var hintFadeTask: Task<Void, Never>?

    private static let hintVisibleSeconds: Double = 3
    private static let escapeKeyCode: UInt16 = 53
    private static let spaceKeyCode: UInt16 = 49

    // MARK: - Start and stop

    /// Covers every display, hides the Dock, menu bar and cursor, and starts watching for
    /// Escape or Space. Does nothing if already running.
    func start() {
        guard !isRunning else { return }
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        makeWindows()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { [weak self] event in
            // Local monitors run on the main thread.
            let consumed = MainActor.assumeIsolated { self?.consumes(event) ?? false }
            return consumed ? nil : event
        }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            },
            // A display was added, removed or rearranged: cover the new layout.
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuildWindows() }
            },
        ]
        showHint()
    }

    /// Closes the covering windows, restores the Dock, menu bar and cursor, then calls
    /// ``onEnd``. Does nothing if not running.
    func stop() {
        guard isRunning else { return }
        hintFadeTask?.cancel()
        hintFadeTask = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        tearDownWindows()
        NSApp.presentationOptions = savedPresentationOptions
        NSCursor.setHiddenUntilMouseMoves(false)
        onEnd?()
    }

    // MARK: - Windows

    private func makeWindows() {
        for screen in NSScreen.screens {
            let window = SaverWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            // Swift owns the window; AppKit's extra release on close would over-release it.
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.setFrame(screen.frame, display: false)

            let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            guard let view = RetroSVRView(frame: container.bounds, isPreview: false) else { continue }
            view.stopsWithSystemSaver = false
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)

            let hint = ExitHintView()
            hint.translatesAutoresizingMaskIntoConstraints = false
            hint.alphaValue = 0
            container.addSubview(hint)
            NSLayoutConstraint.activate([
                hint.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                hint.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -max(48, screen.frame.height * 0.08)),
            ])

            window.contentView = container
            window.orderFrontRegardless()
            view.startAnimation()

            windows.append(window)
            views.append(view)
            hints.append(hint)
        }
        // Keyboard focus goes to the window on the display that had it (`NSScreen.main`), so
        // Escape and Space reach the app.
        (windows.first { $0.screen == NSScreen.main } ?? windows.first)?.makeKey()
        NSCursor.setHiddenUntilMouseMoves(true)
    }

    private func tearDownWindows() {
        views.forEach { $0.stopAnimation() }
        windows.forEach { $0.close() }
        views = []
        hints = []
        windows = []
    }

    private func rebuildWindows() {
        guard isRunning else { return }
        tearDownWindows()
        makeWindows()
        showHint()
    }

    // MARK: - Input

    /// Reacts to `event` and returns whether the saver consumed it. Consumed keys don't beep
    /// or reach the menu.
    private func consumes(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            // Leave ⌘-shortcuts (⌘Q, ⌘H) to the menu.
            if event.modifierFlags.contains(.command) { return false }
            if event.keyCode == Self.escapeKeyCode || event.keyCode == Self.spaceKeyCode {
                stop()
            } else {
                showHint()
            }
            return true
        case .mouseMoved:
            showHint()
            return false
        default:
            return false
        }
    }

    // MARK: - Hint

    private func showHint() {
        hintFadeTask?.cancel()
        setHintAlpha(1, duration: 0.2)
        hintFadeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.hintVisibleSeconds))
            guard !Task.isCancelled, let self, self.isRunning else { return }
            self.setHintAlpha(0, duration: 0.6)
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    private func setHintAlpha(_ alpha: CGFloat, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            for hint in hints {
                hint.animator().alphaValue = alpha
            }
        }
    }
}

/// A borderless window that can still take keyboard focus.
private final class SaverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
