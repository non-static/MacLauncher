import Combine
import Foundation

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var apps: [AppItem] = []
    @Published public private(set) var groups: [AppGroup] = []
    @Published public private(set) var selectedAppID: AppItem.ID?
    @Published public private(set) var hiddenAppCount = 0
    @Published public private(set) var hiddenAppIDs: Set<AppItem.ID> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var loadTimeMilliseconds: Int?
    @Published public var searchQuery = "" {
        didSet {
            applySearch()
        }
    }
    @Published public var errorMessage: String?

    private let catalogService: any AppCatalogService
    private let launchService: any AppLaunchService
    private let layoutStore: (any LayoutStore)?
    private let catalogCacheStore: (any CatalogCacheStore)?
    private let onSuccessfulLaunch: @MainActor () -> Void
    private var discoveredApps: [AppItem] = []
    private var visibleApps: [AppItem] = []
    private var searchableApps: [AppItem] = []
    private var layout = LauncherLayout()
    private var didAttemptLayoutLoad = false
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var showsSystemApps = true
    private var showsHiddenApps = false

    public var totalAppCount: Int {
        searchableApps.count
    }

    public var selectedApp: AppItem? {
        guard let selectedAppID else {
            return nil
        }
        return apps.first { $0.id == selectedAppID }
    }

    public func group(for groupID: AppGroup.ID) -> AppGroup? {
        groups.first { $0.id == groupID }
    }

    public func apps(inGroupID groupID: AppGroup.ID) -> [AppItem] {
        guard let group = group(for: groupID) else {
            return []
        }

        let appsByID = Dictionary(uniqueKeysWithValues: discoveredApps.map { ($0.id, $0) })
        return group.appIDs.compactMap { appID in
            appsByID[appID]
        }
        .filter { app in
            isIncludedByDisplayOptions(app)
        }
    }

    public init(
        catalogService: any AppCatalogService,
        launchService: any AppLaunchService,
        layoutStore: (any LayoutStore)? = nil,
        catalogCacheStore: (any CatalogCacheStore)? = nil,
        onSuccessfulLaunch: @escaping @MainActor () -> Void = {}
    ) {
        self.catalogService = catalogService
        self.launchService = launchService
        self.layoutStore = layoutStore
        self.catalogCacheStore = catalogCacheStore
        self.onSuccessfulLaunch = onSuccessfulLaunch
    }

    @discardableResult
    public func refresh() -> Task<Void, Never> {
        refreshTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration
        let catalogService = catalogService
        let loadStart = ContinuousClock.now

        loadLayoutIfNeeded()
        loadCachedCatalogIfAvailable(loadStart: loadStart)
        isLoading = true

        let task = Task { [weak self, catalogService] in
            guard let self else {
                return
            }

            await self.performRefresh(
                using: catalogService,
                generation: generation,
                loadStart: loadStart
            )
        }
        refreshTask = task
        return task
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
        removeAppIDFromGroups(app.id)
        saveLayout()
        applyLayoutAndSearch()
    }

    public func unhideApp(_ app: AppItem) {
        guard layout.hiddenAppIDs.remove(app.id) != nil else {
            return
        }

        saveLayout()
        applyLayoutAndSearch()
    }

    public func toggleHiddenApp(_ app: AppItem) {
        if layout.hiddenAppIDs.contains(app.id) {
            unhideApp(app)
        } else {
            hideApp(app)
        }
    }

    @discardableResult
    public func createGroupFromSelectedApp() -> AppGroup? {
        guard let selectedApp else {
            return nil
        }
        return createGroup(containing: selectedApp)
    }

    @discardableResult
    public func createGroup(containing app: AppItem) -> AppGroup {
        let groupName = uniqueGroupName(basedOn: "New Group")
        let group = AppGroup(name: groupName, appIDs: [app.id])

        removeAppIDFromGroups(app.id)
        layout.groups.append(group)
        saveLayout()
        applyLayoutAndSearch()
        return group
    }

    public func moveSelectedAppToGroup(groupID: AppGroup.ID) {
        guard let selectedApp else {
            return
        }
        moveApp(selectedApp, toGroup: groupID)
    }

    public func moveApp(_ app: AppItem, toGroup groupID: AppGroup.ID) {
        moveApp(appID: app.id, toGroup: groupID)
    }

    public func moveApp(appID: AppItem.ID, toGroup groupID: AppGroup.ID) {
        guard let groupIndex = layout.groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        guard discoveredApps.contains(where: { $0.id == appID }),
              layout.hiddenAppIDs.contains(appID) == false
        else {
            return
        }

        removeAppIDFromGroups(appID)
        layout.groups[groupIndex].appIDs.append(appID)
        layout.groups[groupIndex].appIDs = uniqueAppIDs(layout.groups[groupIndex].appIDs)
        saveLayout()
        applyLayoutAndSearch()
    }

    public func removeAppFromGroup(appID: AppItem.ID, groupID: AppGroup.ID) {
        guard let groupIndex = layout.groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        layout.groups[groupIndex].appIDs.removeAll { $0 == appID }
        saveLayout()
        applyLayoutAndSearch()
        selectedAppID = appID
    }

    public func renameGroup(groupID: AppGroup.ID, name: String) {
        guard let groupIndex = layout.groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return
        }

        layout.groups[groupIndex].name = uniqueGroupName(
            basedOn: trimmedName,
            excluding: groupID
        )
        saveLayout()
        applyLayoutAndSearch()
    }

    public func deleteGroup(groupID: AppGroup.ID) {
        layout.groups.removeAll { $0.id == groupID }
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

        let insertionIndex = currentIndex < targetIndex ? targetIndex + 1 : targetIndex
        return reorderAppInLayout(draggedAppID: draggedAppID, targetIndex: insertionIndex)
    }

    @discardableResult
    public func reorderAppInLayout(
        draggedAppID: AppItem.ID,
        targetIndex: Int
    ) -> Bool {
        guard let currentIndex = visibleApps.firstIndex(where: { $0.id == draggedAppID }),
              targetIndex >= 0,
              targetIndex <= visibleApps.count,
              targetIndex != currentIndex,
              targetIndex != currentIndex + 1
        else {
            return false
        }

        var reorderedApps = visibleApps
        let movedApp = reorderedApps.remove(at: currentIndex)
        let insertionIndex = targetIndex > currentIndex ? targetIndex - 1 : targetIndex
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

    public func setDisplayOptions(
        showsSystemApps: Bool,
        showsHiddenApps: Bool
    ) {
        guard self.showsSystemApps != showsSystemApps ||
              self.showsHiddenApps != showsHiddenApps
        else {
            return
        }

        self.showsSystemApps = showsSystemApps
        self.showsHiddenApps = showsHiddenApps
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
    public func launchApp(appID: AppItem.ID, fromGroupID groupID: AppGroup.ID) -> Task<Void, Never>? {
        guard apps(inGroupID: groupID).contains(where: { $0.id == appID }),
              let app = discoveredApps.first(where: { $0.id == appID })
        else {
            return nil
        }
        return launch(app)
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
            apps = searchableApps.filter { app in
                app.name.range(
                    of: trimmedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
        }
        reconcileSelection()
    }

    private func performRefresh(
        using catalogService: any AppCatalogService,
        generation: Int,
        loadStart: ContinuousClock.Instant
    ) async {
        defer {
            completeRefresh(generation: generation)
        }

        do {
            let refreshSignpostID = LauncherPerformanceSignposts.begin("Catalog Refresh")
            defer {
                LauncherPerformanceSignposts.end("Catalog Refresh", refreshSignpostID)
            }

            let scannedApps = try await Self.scanInstalledApps(using: catalogService)
            guard generation == refreshGeneration, Task.isCancelled == false else {
                return
            }

            discoveredApps = scannedApps
            applyLayoutAndSearch()
            saveCatalogCache(apps: scannedApps)
            if loadTimeMilliseconds == nil {
                recordLoadTime(from: loadStart)
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == refreshGeneration else {
                return
            }
            errorMessage = "Could not refresh apps: \(error.localizedDescription)"
        }
    }

    nonisolated private static func scanInstalledApps(
        using catalogService: any AppCatalogService
    ) async throws -> [AppItem] {
        let scanTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let apps = try catalogService.installedApps()
            try Task.checkCancellation()
            return apps
        }

        return try await withTaskCancellationHandler {
            try await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }

    private func completeRefresh(generation: Int) {
        guard generation == refreshGeneration else {
            return
        }

        isLoading = false
        refreshTask = nil
    }

    private func loadCachedCatalogIfAvailable(
        loadStart: ContinuousClock.Instant
    ) {
        guard discoveredApps.isEmpty,
              let catalogCacheStore
        else {
            loadTimeMilliseconds = nil
            return
        }

        let cacheSignpostID = LauncherPerformanceSignposts.begin("Catalog Cache Load")
        defer {
            LauncherPerformanceSignposts.end("Catalog Cache Load", cacheSignpostID)
        }

        do {
            guard let snapshot = try catalogCacheStore.loadCatalogSnapshot(),
                  snapshot.apps.isEmpty == false
            else {
                loadTimeMilliseconds = nil
                return
            }

            discoveredApps = snapshot.apps
            applyLayoutAndSearch()
            recordLoadTime(from: loadStart)
            errorMessage = nil
        } catch {
            loadTimeMilliseconds = nil
        }
    }

    private func saveCatalogCache(apps: [AppItem]) {
        guard let catalogCacheStore else {
            return
        }

        let snapshot = AppCatalogSnapshot(apps: apps)
        Task.detached(priority: .utility) {
            let cacheSignpostID = LauncherPerformanceSignposts.begin("Catalog Cache Save")
            defer {
                LauncherPerformanceSignposts.end("Catalog Cache Save", cacheSignpostID)
            }

            try? catalogCacheStore.saveCatalogSnapshot(snapshot)
        }
    }

    private func recordLoadTime(from loadStart: ContinuousClock.Instant) {
        let duration = loadStart.duration(to: ContinuousClock.now)
        let milliseconds = duration.components.seconds * 1_000
            + duration.components.attoseconds / 1_000_000_000_000_000
        loadTimeMilliseconds = Int(milliseconds)
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

        normalizeGroups(availableAppIDs: Set(allOrderedApps.map(\.id)))
        groups = layout.groups

        let groupedAppIDs = Set(layout.groups.flatMap(\.appIDs))
        let appsIncludedBySystemSetting = allOrderedApps.filter { app in
            showsSystemApps || isSystemApp(app) == false
        }
        let displayableApps = appsIncludedBySystemSetting.filter(isIncludedByDisplayOptions)
        searchableApps = displayableApps
        visibleApps = searchableApps.filter { app in
            groupedAppIDs.contains(app.id) == false
        }
        hiddenAppIDs = layout.hiddenAppIDs
        hiddenAppCount = appsIncludedBySystemSetting.filter { layout.hiddenAppIDs.contains($0.id) }.count
        applySearch()
    }

    private func isIncludedByDisplayOptions(_ app: AppItem) -> Bool {
        if showsSystemApps == false, isSystemApp(app) {
            return false
        }

        if showsHiddenApps == false, layout.hiddenAppIDs.contains(app.id) {
            return false
        }

        return true
    }

    private func isSystemApp(_ app: AppItem) -> Bool {
        let path = app.appURL.standardizedFileURL.path
        return path == "/System/Applications" || path.hasPrefix("/System/Applications/")
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

    private func removeAppIDFromGroups(_ appID: AppItem.ID) {
        for groupIndex in layout.groups.indices {
            layout.groups[groupIndex].appIDs.removeAll { $0 == appID }
        }
    }

    private func normalizeGroups(availableAppIDs: Set<AppItem.ID>) {
        var didChange = false

        for groupIndex in layout.groups.indices {
            let normalizedAppIDs = uniqueAppIDs(
                layout.groups[groupIndex].appIDs.filter { availableAppIDs.contains($0) }
            )

            if normalizedAppIDs != layout.groups[groupIndex].appIDs {
                layout.groups[groupIndex].appIDs = normalizedAppIDs
                didChange = true
            }
        }

        if didChange {
            saveLayout()
        }
    }

    private func uniqueAppIDs(_ appIDs: [AppItem.ID]) -> [AppItem.ID] {
        var seenAppIDs = Set<AppItem.ID>()
        return appIDs.filter { seenAppIDs.insert($0).inserted }
    }

    private func uniqueGroupName(
        basedOn baseName: String,
        excluding excludedGroupID: AppGroup.ID? = nil
    ) -> String {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedBaseName.isEmpty ? "New Group" : trimmedBaseName
        let existingNames = Set(
            layout.groups.compactMap { group in
                group.id == excludedGroupID ? nil : group.name
            }
        )

        guard existingNames.contains(baseName) else {
            return baseName
        }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }
}
