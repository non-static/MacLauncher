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

        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
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
