import Combine
import Foundation

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var apps: [AppItem] = []
    @Published public private(set) var selectedAppID: AppItem.ID?
    @Published public private(set) var isLoading = false
    @Published public var searchQuery = "" {
        didSet {
            applySearch()
        }
    }
    @Published public var errorMessage: String?

    private let catalogService: any AppCatalogService
    private let launchService: any AppLaunchService
    private let onSuccessfulLaunch: @MainActor () -> Void
    private var allApps: [AppItem] = []

    public var totalAppCount: Int {
        allApps.count
    }

    public var selectedApp: AppItem? {
        guard let selectedAppID else {
            return nil
        }
        return apps.first { $0.id == selectedAppID }
    }

    public init(
        catalogService: any AppCatalogService,
        launchService: any AppLaunchService,
        onSuccessfulLaunch: @escaping @MainActor () -> Void = {}
    ) {
        self.catalogService = catalogService
        self.launchService = launchService
        self.onSuccessfulLaunch = onSuccessfulLaunch
    }

    public func refresh() {
        isLoading = true
        defer { isLoading = false }

        do {
            allApps = try catalogService.installedApps()
            applySearch()
            errorMessage = nil
        } catch {
            errorMessage = "Could not refresh apps: \(error.localizedDescription)"
        }
    }

    public func moveSelection(by offset: Int) {
        guard apps.isEmpty == false else {
            selectedAppID = nil
            return
        }

        let currentIndex = selectedAppID
            .flatMap { selectedAppID in
                apps.firstIndex { $0.id == selectedAppID }
            } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), apps.count - 1)
        selectedAppID = apps[nextIndex].id
    }

    @discardableResult
    public func launchSelected() -> Task<Void, Never>? {
        guard let selectedApp else {
            return nil
        }
        return launch(selectedApp)
    }

    @discardableResult
    public func launch(_ app: AppItem) -> Task<Void, Never> {
        Task {
            do {
                try await launchService.launch(app)
                errorMessage = nil
                onSuccessfulLaunch()
            } catch {
                errorMessage = "Could not launch \(app.name): \(error.localizedDescription)"
            }
        }
    }

    private func applySearch() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            apps = allApps
        } else {
            apps = allApps.filter { app in
                app.name.range(
                    of: trimmedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
        }
        reconcileSelection()
    }

    private func reconcileSelection() {
        guard apps.isEmpty == false else {
            selectedAppID = nil
            return
        }

        if let selectedAppID, apps.contains(where: { $0.id == selectedAppID }) {
            return
        }

        selectedAppID = apps[0].id
    }
}
