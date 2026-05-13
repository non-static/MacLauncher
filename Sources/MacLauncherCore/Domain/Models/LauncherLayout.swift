import Foundation

public struct LauncherLayout: Codable, Equatable, Sendable {
    public var orderedAppIDs: [String]
    public var groups: [AppGroup]
    public var hiddenAppIDs: Set<String>
    public var version: Int

    public init(
        orderedAppIDs: [String] = [],
        groups: [AppGroup] = [],
        hiddenAppIDs: Set<String> = [],
        version: Int = 1
    ) {
        self.orderedAppIDs = orderedAppIDs
        self.groups = groups
        self.hiddenAppIDs = hiddenAppIDs
        self.version = version
    }
}
