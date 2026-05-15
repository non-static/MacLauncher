import Foundation

public final class JSONCatalogCacheStore: CatalogCacheStore, @unchecked Sendable {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileManager: FileManager = .default,
        fileURL: URL = JSONCatalogCacheStore.defaultFileURL()
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public static func defaultFileURL(appName: String = "MacLauncher") -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return appSupport
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("catalog-cache.json", isDirectory: false)
    }

    public func loadCatalogSnapshot() throws -> AppCatalogSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(AppCatalogSnapshot.self, from: data)
            guard snapshot.version == AppCatalogSnapshot.currentVersion else {
                return nil
            }
            return snapshot
        } catch {
            return nil
        }
    }

    public func saveCatalogSnapshot(_ snapshot: AppCatalogSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
