import AppKit

public protocol AppIconLoading: Sendable {
    func icon(for app: AppItem) -> NSImage
}
