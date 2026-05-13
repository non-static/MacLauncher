import AppKit

public final class NSWorkspaceAppIconLoader: AppIconLoading {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func icon(for app: AppItem) -> NSImage {
        let icon = workspace.icon(forFile: app.appURL.path)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }
}
