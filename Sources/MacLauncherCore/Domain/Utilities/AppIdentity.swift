import Foundation

public enum AppIdentity {
    public static func makeID(bundleIdentifier: String?, appURL: URL) -> String {
        if let bundleIdentifier,
           bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return bundleIdentifier
        }

        let path = canonicalPath(for: appURL)
        if path.isEmpty == false {
            return path
        }

        return "generated:\(StableHash.fnv1a64Hex(appURL.absoluteString))"
    }

    public static func canonicalPath(for appURL: URL) -> String {
        appURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }
}
