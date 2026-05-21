import Foundation

public enum LauncherTileSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var metrics: LauncherTileMetrics {
        switch self {
        case .small:
            LauncherTileMetrics(
                minWidth: 96,
                width: 88,
                height: 104,
                iconLength: 52,
                labelWidth: 82,
                labelHeight: 36
            )
        case .medium:
            LauncherTileMetrics(
                minWidth: 112,
                width: 104,
                height: 120,
                iconLength: 64,
                labelWidth: 96,
                labelHeight: 38
            )
        case .large:
            LauncherTileMetrics(
                minWidth: 136,
                width: 128,
                height: 148,
                iconLength: 80,
                labelWidth: 118,
                labelHeight: 44
            )
        }
    }
}

public enum LauncherColumnMode: String, CaseIterable, Identifiable, Sendable {
    case adaptive
    case fixed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .adaptive: "Adaptive"
        case .fixed: "Fixed"
        }
    }
}

public enum LauncherHotkeyOption: String, CaseIterable, Identifiable, Sendable {
    case none
    case commandShiftSpace
    case optionSpace
    case controlSpace

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: "None"
        case .commandShiftSpace: "Command Shift Space"
        case .optionSpace: "Option Space"
        case .controlSpace: "Control Space"
        }
    }
}

public struct LauncherGridConfiguration: Equatable, Sendable {
    public static let `default` = LauncherGridConfiguration()

    public let tileSize: LauncherTileSize
    public let columnMode: LauncherColumnMode
    public let fixedColumnCount: Int

    public init(
        tileSize: LauncherTileSize = .medium,
        columnMode: LauncherColumnMode = .adaptive,
        fixedColumnCount: Int = 5
    ) {
        self.tileSize = tileSize
        self.columnMode = columnMode
        self.fixedColumnCount = min(max(fixedColumnCount, 2), 8)
    }

    var metrics: LauncherTileMetrics {
        tileSize.metrics
    }
}

struct LauncherTileMetrics: Equatable, Sendable {
    let minWidth: CGFloat
    let width: CGFloat
    let height: CGFloat
    let iconLength: CGFloat
    let labelWidth: CGFloat
    let labelHeight: CGFloat
}
