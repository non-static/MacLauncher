import Foundation

public struct AppCatalogSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let generatedAt: Date
    public let apps: [AppItem]

    public init(
        version: Int = AppCatalogSnapshot.currentVersion,
        generatedAt: Date = Date(),
        apps: [AppItem]
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.apps = apps
    }
}
