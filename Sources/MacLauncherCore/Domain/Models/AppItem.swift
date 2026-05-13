import Foundation

public struct AppItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String?
    public let appURL: URL
    public let iconCacheKey: String

    public init(
        id: String,
        name: String,
        bundleIdentifier: String?,
        appURL: URL,
        iconCacheKey: String
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.appURL = appURL
        self.iconCacheKey = iconCacheKey
    }
}
