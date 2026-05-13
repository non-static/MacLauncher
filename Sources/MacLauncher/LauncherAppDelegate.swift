import AppKit

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
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

            NSApp.terminate(nil)
            return nil
        }
    }
}
