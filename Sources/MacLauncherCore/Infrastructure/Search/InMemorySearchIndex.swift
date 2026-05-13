import Foundation

public final class InMemorySearchIndex: SearchIndex {
    private var apps: [AppItem]

    public init(apps: [AppItem] = []) {
        self.apps = apps
    }

    public func replaceAll(with apps: [AppItem]) {
        self.apps = apps
    }

    public func search(_ query: String) -> [AppItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.isEmpty == false else {
            return apps
        }

        return apps.filter {
            $0.name.range(
                of: normalizedQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }
}
