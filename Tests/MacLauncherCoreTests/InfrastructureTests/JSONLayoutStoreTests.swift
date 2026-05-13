import Foundation
@testable import MacLauncherCore
import Testing

struct JSONLayoutStoreTests {
    @Test
    func saveAndLoadRoundTrip() throws {
        let fileURL = try temporaryFileURL()
        let store = JSONLayoutStore(fileURL: fileURL)
        let layout = LauncherLayout(
            orderedAppIDs: ["com.example.one", "com.example.two"],
            groups: [],
            hiddenAppIDs: ["com.example.hidden"],
            version: 1
        )

        try store.saveLayout(layout)
        let loaded = try store.loadLayout()

        #expect(loaded == layout)
    }

    @Test
    func corruptJSONReturnsNil() throws {
        let fileURL = try temporaryFileURL()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: fileURL)
        let store = JSONLayoutStore(fileURL: fileURL)

        let loaded = try store.loadLayout()

        #expect(loaded == nil)
    }

    private func temporaryFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("layout.json")
    }
}
