import Foundation
@testable import MacLauncherCore
import Testing

struct NSWorkspaceCatalogServiceTests {
    @Test
    func scansAppBundlesFromConfiguredDirectory() throws {
        let directory = try makeTemporaryDirectory()
        try makeAppBundle(
            in: directory,
            bundleName: "Example.app",
            bundleIdentifier: "com.example.launcher-test",
            displayName: "Example"
        )
        let service = NSWorkspaceCatalogService(scanDirectories: [directory])

        let apps = try service.installedApps()

        #expect(apps.count == 1)
        #expect(apps[0].id == "com.example.launcher-test")
        #expect(apps[0].name == "Example")
        #expect(apps[0].bundleIdentifier == "com.example.launcher-test")
    }

    @Test
    func missingMetadataFallsBackToFileName() throws {
        let directory = try makeTemporaryDirectory()
        let appURL = directory.appendingPathComponent("Bare.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: appURL,
            withIntermediateDirectories: true
        )
        let service = NSWorkspaceCatalogService(scanDirectories: [directory])

        let apps = try service.installedApps()

        #expect(apps.count == 1)
        #expect(apps[0].name == "Bare")
        #expect(apps[0].bundleIdentifier == nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func makeAppBundle(
        in directory: URL,
        bundleName: String,
        bundleIdentifier: String,
        displayName: String
    ) throws {
        let contentsURL = directory
            .appendingPathComponent(bundleName, isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contentsURL,
            withIntermediateDirectories: true
        )

        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": displayName,
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
    }
}
