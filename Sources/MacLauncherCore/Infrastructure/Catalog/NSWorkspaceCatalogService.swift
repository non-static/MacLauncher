import AppKit
import Foundation

public final class NSWorkspaceCatalogService: AppCatalogService, @unchecked Sendable {
    private let fileManager: FileManager
    private let scanDirectories: [URL]

    public init(
        fileManager: FileManager = .default,
        scanDirectories: [URL] = NSWorkspaceCatalogService.defaultScanDirectories()
    ) {
        self.fileManager = fileManager
        self.scanDirectories = scanDirectories
    }

    public static func defaultScanDirectories() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    public func installedApps() throws -> [AppItem] {
        var appsByID: [String: AppItem] = [:]

        for directory in scanDirectories {
            for appURL in appURLs(in: directory) {
                guard let app = makeAppItem(from: appURL), appsByID[app.id] == nil else {
                    continue
                }
                appsByID[app.id] = app
            }
        }

        return appsByID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func appURLs(in directory: URL) -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        if directory.pathExtension.lowercased() == "app" {
            return [directory]
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "app" {
                urls.append(url)
                enumerator.skipDescendants()
            }
        }
        return urls
    }

    private func makeAppItem(from appURL: URL) -> AppItem? {
        let canonicalURL = appURL.resolvingSymlinksInPath().standardizedFileURL
        let bundle = Bundle(url: canonicalURL)
        let bundleIdentifier = bundle?.bundleIdentifier
        let name = displayName(for: canonicalURL, bundle: bundle)
        let id = AppIdentity.makeID(
            bundleIdentifier: bundleIdentifier,
            appURL: canonicalURL
        )

        return AppItem(
            id: id,
            name: name,
            bundleIdentifier: bundleIdentifier,
            appURL: canonicalURL,
            iconCacheKey: bundleIdentifier ?? AppIdentity.canonicalPath(for: canonicalURL)
        )
    }

    private func displayName(for appURL: URL, bundle: Bundle?) -> String {
        let localizedName = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
        let bundleName = bundle?.infoDictionary?["CFBundleName"] as? String
        let finderName = fileManager.displayName(atPath: appURL.path)
        let fallbackName = appURL.deletingPathExtension().lastPathComponent

        return [
            localizedName,
            displayName,
            bundleName,
            finderName,
            fallbackName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { $0.isEmpty == false } ?? fallbackName
    }
}
