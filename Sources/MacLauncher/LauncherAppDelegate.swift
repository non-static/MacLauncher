import AppKit

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installRuntimeAppIcon()
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

    private func installRuntimeAppIcon() {
        guard
            let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }
}
