import Foundation

public final class JSONLayoutStore: LayoutStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileManager: FileManager = .default,
        fileURL: URL = JSONLayoutStore.defaultFileURL()
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public static func defaultFileURL(appName: String = "MacLauncher") -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return appSupport
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("layout.json", isDirectory: false)
    }

    public func loadLayout() throws -> LauncherLayout? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LauncherLayout.self, from: data)
        } catch {
            return nil
        }
    }

    public func saveLayout(_ layout: LauncherLayout) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(layout)
        try data.write(to: fileURL, options: [.atomic])
    }
}
