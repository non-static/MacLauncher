import Combine
import Foundation

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var apps: [AppItem] = []
    @Published public private(set) var selectedAppID: AppItem.ID?
    @Published public private(set) var hiddenAppCount = 0
    @Published public private(set) var isLoading = false
    @Published public var searchQuery = "" {
        didSet {
            applySearch()
        }
    }
    @Published public var errorMessage: String?

    private let catalogService: any AppCatalogService
    private let launchService: any AppLaunchService
    private let layoutStore: (any LayoutStore)?
    private let onSuccessfulLaunch: @MainActor () -> Void
    private var discoveredApps: [AppItem] = []
    private var visibleApps: [AppItem] = []
    private var layout = LauncherLayout()
    private var didAttemptLayoutLoad = false

    public var totalAppCount: Int {
        visibleApps.count
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
        layoutStore: (any LayoutStore)? = nil,
        onSuccessfulLaunch: @escaping @MainActor () -> Void = {}
    ) {
        self.catalogService = catalogService
        self.launchService = launchService
        self.layoutStore = layoutStore
        self.onSuccessfulLaunch = onSuccessfulLaunch
    }

    public func refresh() {
        isLoading = true
        defer { isLoading = false }

        do {
            loadLayoutIfNeeded()
            discoveredApps = try catalogService.installedApps()
            applyLayoutAndSearch()
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

    public func hideSelectedApp() {
        guard let selectedApp else {
            return
        }
        hideApp(selectedApp)
    }

    public func hideApp(_ app: AppItem) {
        layout.hiddenAppIDs.insert(app.id)
        saveLayout()
        applyLayoutAndSearch()
    }

    public func moveSelectedAppInLayout(by offset: Int) {
        guard let selectedApp else {
            return
        }
        moveAppInLayout(selectedApp, by: offset)
    }

    public func moveAppInLayout(_ app: AppItem, by offset: Int) {
        guard let currentIndex = visibleApps.firstIndex(where: { $0.id == app.id }) else {
            return
        }

        let targetIndex = min(max(currentIndex + offset, 0), visibleApps.count - 1)
        guard targetIndex != currentIndex else {
            return
        }

        var reorderedApps = visibleApps
        let movedApp = reorderedApps.remove(at: currentIndex)
        reorderedApps.insert(movedApp, at: targetIndex)
        let hiddenOrderedIDs = layout.orderedAppIDs.filter { layout.hiddenAppIDs.contains($0) }

        layout.orderedAppIDs = reorderedApps.map(\.id) + hiddenOrderedIDs
        saveLayout()
        applyLayoutAndSearch()
        selectedAppID = app.id
    }

    @discardableResult
    public func reorderAppInLayout(
        draggedAppID: AppItem.ID,
        targetAppID: AppItem.ID
    ) -> Bool {
        guard draggedAppID != targetAppID,
              let currentIndex = visibleApps.firstIndex(where: { $0.id == draggedAppID }),
              let targetIndex = visibleApps.firstIndex(where: { $0.id == targetAppID })
        else {
            return false
        }

        var reorderedApps = visibleApps
        let movedApp = reorderedApps.remove(at: currentIndex)
        let insertionIndex = min(targetIndex, reorderedApps.count)
        reorderedApps.insert(movedApp, at: insertionIndex)
        let hiddenOrderedIDs = layout.orderedAppIDs.filter { layout.hiddenAppIDs.contains($0) }

        layout.orderedAppIDs = reorderedApps.map(\.id) + hiddenOrderedIDs
        saveLayout()
        applyLayoutAndSearch()
        selectedAppID = draggedAppID
        return true
    }

    public func resetLayout() {
        layout = LauncherLayout(orderedAppIDs: discoveredApps.map(\.id))
        saveLayout()
        applyLayoutAndSearch()
    }

    @discardableResult
    public func resetSearchToLoadedState() -> Bool {
        guard searchQuery.isEmpty == false else {
            return false
        }

        searchQuery = ""
        selectedAppID = apps.first?.id
        return true
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
            apps = visibleApps
        } else {
            apps = visibleApps.filter { app in
                app.name.range(
                    of: trimmedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
        }
        reconcileSelection()
    }

    private func loadLayoutIfNeeded() {
        guard didAttemptLayoutLoad == false else {
            return
        }

        didAttemptLayoutLoad = true

        do {
            let loadedLayout = try layoutStore?.loadLayout()
            if let loadedLayout, loadedLayout.version == LauncherLayout.currentVersion {
                layout = loadedLayout
            } else {
                layout = LauncherLayout()
            }
        } catch {
            layout = LauncherLayout()
        }
    }

    private func applyLayoutAndSearch() {
        let appsByID = Dictionary(uniqueKeysWithValues: discoveredApps.map { ($0.id, $0) })
        var seenOrderedIDs = Set<String>()
        let orderedApps = layout.orderedAppIDs.compactMap { appID -> AppItem? in
            guard seenOrderedIDs.insert(appID).inserted else {
                return nil
            }
            return appsByID[appID]
        }
        let orderedIDs = Set(orderedApps.map(\.id))
        let newApps = discoveredApps.filter { orderedIDs.contains($0.id) == false }
        let allOrderedApps = orderedApps + newApps

        if allOrderedApps.map(\.id) != layout.orderedAppIDs {
            layout.orderedAppIDs = allOrderedApps.map(\.id)
            saveLayout()
        }

        visibleApps = allOrderedApps.filter { layout.hiddenAppIDs.contains($0.id) == false }
        hiddenAppCount = allOrderedApps.count - visibleApps.count
        applySearch()
    }

    private func saveLayout() {
        do {
            try layoutStore?.saveLayout(layout)
        } catch {
            errorMessage = "Could not save layout: \(error.localizedDescription)"
        }
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
