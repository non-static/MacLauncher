import Foundation

public struct LauncherLayout: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var orderedAppIDs: [String]
    public var groups: [AppGroup]
    public var hiddenAppIDs: Set<String>
    public var version: Int

    public init(
        orderedAppIDs: [String] = [],
        groups: [AppGroup] = [],
        hiddenAppIDs: Set<String> = [],
        version: Int = LauncherLayout.currentVersion
    ) {
        self.orderedAppIDs = orderedAppIDs
        self.groups = groups
        self.hiddenAppIDs = hiddenAppIDs
        self.version = version
    }
}
