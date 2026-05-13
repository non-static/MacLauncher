import AppKit

public protocol AppIconLoading {
    func icon(for app: AppItem) -> NSImage
}
