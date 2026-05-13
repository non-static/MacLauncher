import AppKit

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        focusWindowsAfterLaunch()
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
}
