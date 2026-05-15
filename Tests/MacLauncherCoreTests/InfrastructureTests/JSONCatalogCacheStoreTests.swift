import Foundation
@testable import MacLauncherCore
import Testing

struct JSONCatalogCacheStoreTests {
    @Test
    func missingCatalogCacheReturnsNil() throws {
        let store = JSONCatalogCacheStore(fileURL: try makeTemporaryFileURL())

        let snapshot = try store.loadCatalogSnapshot()

        #expect(snapshot == nil)
    }

    @Test
    func savesAndLoadsCatalogSnapshot() throws {
        let fileURL = try makeTemporaryFileURL()
        let store = JSONCatalogCacheStore(fileURL: fileURL)
        let snapshot = AppCatalogSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            apps: [
                AppItem(
                    id: "com.example.cached",
                    name: "Cached",
                    bundleIdentifier: "com.example.cached",
                    appURL: URL(fileURLWithPath: "/Applications/Cached.app"),
                    iconCacheKey: "com.example.cached"
                )
            ]
        )

        try store.saveCatalogSnapshot(snapshot)

        #expect(try store.loadCatalogSnapshot() == snapshot)
    }

    private func makeTemporaryFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("catalog-cache.json")
    }
}
