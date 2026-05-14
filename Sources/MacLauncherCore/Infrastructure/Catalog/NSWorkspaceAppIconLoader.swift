import AppKit

public final class NSWorkspaceAppIconLoader: AppIconLoading {
    private let workspace: NSWorkspace
    private let cache = NSCache<NSString, NSImage>()

    public init(
        workspace: NSWorkspace = .shared,
        cacheLimit: Int = 512
    ) {
        self.workspace = workspace
        self.cache.countLimit = cacheLimit
    }

    public func icon(for app: AppItem) -> NSImage {
        let cacheKey = app.iconCacheKey as NSString
        if let cachedIcon = cache.object(forKey: cacheKey) {
            return cachedIcon
        }

        let icon = workspace.icon(forFile: app.appURL.path)
        icon.size = NSSize(width: 64, height: 64)
        cache.setObject(icon, forKey: cacheKey)
        return icon
    }
}
