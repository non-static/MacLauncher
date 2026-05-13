import Foundation

public struct AppGroup: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var appIDs: [String]

    public init(id: UUID = UUID(), name: String, appIDs: [String]) {
        self.id = id
        self.name = name
        self.appIDs = appIDs
    }
}
