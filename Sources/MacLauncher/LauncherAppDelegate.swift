import AppKit
import Darwin

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    private static var didRequestLaunchTermination = false

    var launcherEscapeHandler: (@MainActor () -> Bool)?

    private var escapeKeyMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installRuntimeAppIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEscapeKeyMonitor()
        focusWindowsAfterLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
        }
    }

    private func focusWindowsAfterLaunch() {
        Task { @MainActor in
            Self.focusWindows()

            try? await Task.sleep(nanoseconds: 200_000_000)
            Self.focusWindows()
        }
    }

    private static func focusWindows() {
        NSApp.activate(ignoringOtherApps: true)
        let preferredScreen = preferredScreen()

        for window in NSApp.windows where window.canBecomeKey {
            if window.identifier == LauncherWindowIdentifiers.launcher,
               let preferredScreen
            {
                center(window, on: preferredScreen)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private static func preferredScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func center(_ window: NSWindow, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
        let origin = NSPoint(
            x: min(max(visibleFrame.midX - (windowSize.width / 2), visibleFrame.minX), maxX),
            y: min(max(visibleFrame.midY - (windowSize.height / 2), visibleFrame.minY), maxY)
        )

        window.setFrameOrigin(origin)
    }

    static func terminateAfterSuccessfulLaunch() {
        guard didRequestLaunchTermination == false else {
            return
        }

        didRequestLaunchTermination = true
        NSApp.terminate(nil)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            Darwin.exit(EXIT_SUCCESS)
        }
    }

    private func installRuntimeAppIcon() {
        guard
            let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }

    private func installEscapeKeyMonitor() {
        guard escapeKeyMonitor == nil else {
            return
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else {
                return event
            }

            if Self.closeVisibleSettingsWindow() {
                return nil
            }

            if self.launcherEscapeHandler?() == true {
                return nil
            }

            NSApp.terminate(nil)
            return nil
        }
    }

    private static func closeVisibleSettingsWindow() -> Bool {
        guard let settingsWindow = NSApp.windows.first(where: {
            $0.identifier == LauncherWindowIdentifiers.settings && $0.isVisible
        }) else {
            return false
        }

        settingsWindow.close()
        return true
    }
}
