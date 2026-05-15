import Foundation
@testable import MacLauncherCore
import Testing

@MainActor
struct HomeViewModelTests {
    @Test
    func refreshLoadsApps() async {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value

        #expect(viewModel.apps == [app])
        #expect(viewModel.totalAppCount == 1)
        #expect(viewModel.selectedAppID == app.id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func refreshShowsLoadingWhileScanning() async {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(
                apps: [app],
                delay: 0.04
            ),
            launchService: StubLaunchService()
        )

        let refreshTask = viewModel.refresh()

        #expect(viewModel.isLoading)

        await refreshTask.value

        #expect(viewModel.isLoading == false)
        #expect(viewModel.apps == [app])
    }

    @Test
    func refreshShowsCachedAppsBeforeScanCompletes() async {
        let cachedApp = makeApp(id: "com.example.cached", name: "Cached")
        let scannedApp = makeApp(id: "com.example.scanned", name: "Scanned")
        let cacheStore = StubCatalogCacheStore(
            snapshot: AppCatalogSnapshot(apps: [cachedApp])
        )
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(
                apps: [scannedApp],
                delay: 0.04
            ),
            launchService: StubLaunchService(),
            catalogCacheStore: cacheStore
        )

        let refreshTask = viewModel.refresh()

        #expect(viewModel.apps == [cachedApp])
        #expect(viewModel.loadTimeMilliseconds != nil)
        #expect(viewModel.isLoading)

        await refreshTask.value

        #expect(viewModel.apps == [scannedApp])
        #expect(viewModel.isLoading == false)
    }

    @Test
    func refreshFailureSetsError() async {
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(error: StubError.failed),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value

        #expect(viewModel.apps.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func refreshAppliesPersistedOrderAndHiddenApps() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore(
            layoutToLoad: LauncherLayout(
                orderedAppIDs: [apps[1].id, apps[0].id, apps[2].id],
                hiddenAppIDs: [apps[2].id]
            )
        )
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value

        #expect(viewModel.apps == [apps[1], apps[0]])
        #expect(viewModel.totalAppCount == 2)
        #expect(viewModel.hiddenAppCount == 1)
        #expect(viewModel.selectedAppID == apps[1].id)
    }

    @Test
    func hideAppPersistsLayoutAndRemovesAppFromGrid() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        viewModel.hideApp(apps[1])

        #expect(viewModel.apps == [apps[0], apps[2]])
        #expect(viewModel.hiddenAppCount == 1)
        #expect(store.savedLayouts.last?.hiddenAppIDs == [apps[1].id])
    }

    @Test
    func createGroupFromSelectedAppPersistsGroupAndRemovesAppFromGrid() async throws {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        viewModel.moveSelection(by: 1)
        let group = try #require(viewModel.createGroupFromSelectedApp())

        #expect(group.name == "New Group")
        #expect(viewModel.groups == [group])
        #expect(viewModel.apps == [apps[0], apps[2]])
        #expect(viewModel.apps(inGroupID: group.id) == [apps[1]])
        #expect(store.savedLayouts.last?.groups == [group])
    }

    @Test
    func moveAppIntoAndOutOfGroupPersistsMembership() async throws {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let group = viewModel.createGroup(containing: apps[0])
        viewModel.moveApp(apps[2], toGroup: group.id)

        #expect(viewModel.apps == [apps[1]])
        #expect(viewModel.apps(inGroupID: group.id) == [apps[0], apps[2]])
        #expect(store.savedLayouts.last?.groups.first?.appIDs == [apps[0].id, apps[2].id])

        viewModel.removeAppFromGroup(appID: apps[0].id, groupID: group.id)

        #expect(viewModel.apps == [apps[0], apps[1]])
        #expect(viewModel.apps(inGroupID: group.id) == [apps[2]])
        #expect(store.savedLayouts.last?.groups.first?.appIDs == [apps[2].id])
    }

    @Test
    func moveAppIDToGroupSupportsDropWithoutOpeningGroup() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let group = viewModel.createGroup(containing: apps[0])
        viewModel.moveApp(appID: apps[1].id, toGroup: group.id)

        #expect(viewModel.apps.isEmpty)
        #expect(viewModel.apps(inGroupID: group.id) == apps)
        #expect(store.savedLayouts.last?.groups.first?.appIDs == apps.map(\.id))
    }

    @Test
    func renameGroupPersistsTrimmedUniqueName() async throws {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let firstGroup = viewModel.createGroup(containing: apps[0])
        _ = viewModel.createGroup(containing: apps[1])
        viewModel.renameGroup(groupID: firstGroup.id, name: "  New Group 2  ")

        #expect(viewModel.group(for: firstGroup.id)?.name == "New Group 2 2")
        #expect(store.savedLayouts.last?.groups.first?.name == "New Group 2 2")
    }

    @Test
    func deleteGroupRestoresGroupedAppsToGrid() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let group = viewModel.createGroup(containing: apps[0])
        viewModel.deleteGroup(groupID: group.id)

        #expect(viewModel.groups.isEmpty)
        #expect(viewModel.apps == apps)
        #expect(store.savedLayouts.last?.groups.isEmpty == true)
    }

    @Test
    func refreshAppliesPersistedGroups() async throws {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let group = AppGroup(
            id: try #require(UUID(uuidString: "C19F3EEA-E1BC-47AB-9298-714B499217A1")),
            name: "Work",
            appIDs: [apps[1].id]
        )
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: StubLayoutStore(
                layoutToLoad: LauncherLayout(
                    orderedAppIDs: apps.map(\.id),
                    groups: [group]
                )
            )
        )

        await viewModel.refresh().value

        #expect(viewModel.groups == [group])
        #expect(viewModel.apps == [apps[0], apps[2]])
        #expect(viewModel.apps(inGroupID: group.id) == [apps[1]])
    }

    @Test
    func moveAppInLayoutPersistsCustomOrder() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        viewModel.moveAppInLayout(apps[2], by: -2)

        #expect(viewModel.apps == [apps[2], apps[0], apps[1]])
        #expect(viewModel.selectedAppID == apps[2].id)
        #expect(store.savedLayouts.last?.orderedAppIDs == [
            apps[2].id,
            apps[0].id,
            apps[1].id
        ])
    }

    @Test
    func reorderAppInLayoutPersistsDroppedOrder() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three"),
            makeApp(id: "com.example.four", name: "Four")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let didReorder = viewModel.reorderAppInLayout(
            draggedAppID: apps[0].id,
            targetAppID: apps[2].id
        )

        #expect(didReorder)
        #expect(viewModel.apps == [apps[1], apps[2], apps[0], apps[3]])
        #expect(viewModel.selectedAppID == apps[0].id)
        #expect(store.savedLayouts.last?.orderedAppIDs == [
            apps[1].id,
            apps[2].id,
            apps[0].id,
            apps[3].id
        ])
    }

    @Test
    func reorderAppInLayoutSurvivesRefreshFromStore() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let firstViewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )
        await firstViewModel.refresh().value
        firstViewModel.reorderAppInLayout(draggedAppID: apps[2].id, targetAppID: apps[0].id)

        let secondViewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )
        await secondViewModel.refresh().value

        #expect(secondViewModel.apps == [apps[2], apps[0], apps[1]])
    }

    @Test
    func reorderAppInLayoutCanMoveAppToFirstIndex() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let didReorder = viewModel.reorderAppInLayout(
            draggedAppID: apps[2].id,
            targetIndex: 0
        )

        #expect(didReorder)
        #expect(viewModel.apps == [apps[2], apps[0], apps[1]])
        #expect(store.savedLayouts.last?.orderedAppIDs == [
            apps[2].id,
            apps[0].id,
            apps[1].id
        ])
    }

    @Test
    func reorderAppInLayoutCanMoveAppAfterLastIndex() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let didReorder = viewModel.reorderAppInLayout(
            draggedAppID: apps[0].id,
            targetIndex: apps.count
        )

        #expect(didReorder)
        #expect(viewModel.apps == [apps[1], apps[2], apps[0]])
        #expect(store.savedLayouts.last?.orderedAppIDs == [
            apps[1].id,
            apps[2].id,
            apps[0].id
        ])
    }

    @Test
    func reorderAppInLayoutRejectsInvalidDropWithoutSaving() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        let store = StubLayoutStore()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        let saveCount = store.savedLayouts.count
        let didReorderSameApp = viewModel.reorderAppInLayout(
            draggedAppID: apps[0].id,
            targetAppID: apps[0].id
        )
        let didReorderUnknownApp = viewModel.reorderAppInLayout(
            draggedAppID: "missing",
            targetAppID: apps[1].id
        )
        let didReorderOutOfRange = viewModel.reorderAppInLayout(
            draggedAppID: apps[0].id,
            targetIndex: apps.count + 1
        )

        #expect(didReorderSameApp == false)
        #expect(didReorderUnknownApp == false)
        #expect(didReorderOutOfRange == false)
        #expect(viewModel.apps == apps)
        #expect(store.savedLayouts.count == saveCount)
    }

    @Test
    func resetLayoutRestoresScannedOrderAndHiddenApps() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let store = StubLayoutStore(
            layoutToLoad: LauncherLayout(
                orderedAppIDs: [apps[2].id, apps[1].id, apps[0].id],
                hiddenAppIDs: [apps[1].id]
            )
        )
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )

        await viewModel.refresh().value
        viewModel.resetLayout()

        #expect(viewModel.apps == apps)
        #expect(viewModel.hiddenAppCount == 0)
        #expect(store.savedLayouts.last == LauncherLayout(orderedAppIDs: apps.map(\.id)))
    }

    @Test
    func loadLayoutFailureFallsBackToScannedApps() async {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService(),
            layoutStore: StubLayoutStore(loadError: StubError.failed)
        )

        await viewModel.refresh().value

        #expect(viewModel.apps == [app])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func unsupportedLayoutVersionFallsBackToScannedApps() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: StubLayoutStore(
                layoutToLoad: LauncherLayout(
                    orderedAppIDs: [apps[1].id],
                    hiddenAppIDs: [apps[0].id],
                    version: 999
                )
            )
        )

        await viewModel.refresh().value

        #expect(viewModel.apps == apps)
        #expect(viewModel.hiddenAppCount == 0)
    }

    @Test
    func searchFiltersAppsByNameAndClearRestoresAllApps() async {
        let apps = [
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal"),
            makeApp(id: "com.example.preview", name: "Preview")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value
        viewModel.searchQuery = "TER"

        #expect(viewModel.apps == [apps[1]])
        #expect(viewModel.selectedAppID == apps[1].id)

        viewModel.searchQuery = ""

        #expect(viewModel.apps == apps)
        #expect(viewModel.totalAppCount == 3)
    }

    @Test
    func searchIncludesGroupedAppsAndClearRestoresUngroupedGrid() async {
        let apps = [
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal"),
            makeApp(id: "com.example.preview", name: "Preview")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value
        viewModel.createGroup(containing: apps[1])
        viewModel.searchQuery = "TER"

        #expect(viewModel.apps == [apps[1]])
        #expect(viewModel.selectedAppID == apps[1].id)
        #expect(viewModel.totalAppCount == 3)

        viewModel.searchQuery = ""

        #expect(viewModel.apps == [apps[0], apps[2]])
    }

    @Test
    func selectionMovesWithinVisibleApps() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedAppID == apps[1].id)

        viewModel.moveSelection(by: 10)
        #expect(viewModel.selectedAppID == apps[2].id)

        viewModel.moveSelection(by: -10)
        #expect(viewModel.selectedAppID == apps[0].id)
    }

    @Test
    func searchReconcilesSelectionToVisibleApps() async {
        let apps = [
            makeApp(id: "com.example.calendar", name: "Calendar"),
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value
        viewModel.moveSelection(by: 2)
        viewModel.searchQuery = "saf"

        #expect(viewModel.apps == [apps[1]])
        #expect(viewModel.selectedAppID == apps[1].id)
    }

    @Test
    func resetSearchToLoadedStateClearsQueryAndSelectsFirstApp() async {
        let apps = [
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal"),
            makeApp(id: "com.example.preview", name: "Preview")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value
        viewModel.moveSelection(by: 2)
        viewModel.searchQuery = "ter"

        let didReset = viewModel.resetSearchToLoadedState()

        #expect(didReset)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.apps == apps)
        #expect(viewModel.selectedAppID == apps[0].id)
    }

    @Test
    func resetSearchToLoadedStateReturnsFalseWhenQueryIsEmpty() async {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService()
        )

        await viewModel.refresh().value

        #expect(viewModel.resetSearchToLoadedState() == false)
        #expect(viewModel.apps == [app])
        #expect(viewModel.selectedAppID == app.id)
    }

    @Test
    func successfulLaunchRunsSuccessHandler() async {
        let app = makeApp()
        var didRunSuccessHandler = false
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(),
            launchService: StubLaunchService(),
            onSuccessfulLaunch: {
                didRunSuccessHandler = true
            }
        )

        await viewModel.launch(app).value

        #expect(didRunSuccessHandler)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func failedLaunchDoesNotRunSuccessHandler() async {
        let app = makeApp()
        var didRunSuccessHandler = false
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(),
            launchService: StubLaunchService(error: StubError.failed),
            onSuccessfulLaunch: {
                didRunSuccessHandler = true
            }
        )

        await viewModel.launch(app).value

        #expect(didRunSuccessHandler == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func launchSelectedLaunchesHighlightedApp() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        var didRunSuccessHandler = false
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            onSuccessfulLaunch: {
                didRunSuccessHandler = true
            }
        )

        await viewModel.refresh().value
        viewModel.moveSelection(by: 1)
        if let task = viewModel.launchSelected() {
            await task.value
        }

        #expect(viewModel.selectedAppID == apps[1].id)
        #expect(didRunSuccessHandler)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func launchGroupedAppRunsSuccessHandler() async {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two")
        ]
        var didRunSuccessHandler = false
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            onSuccessfulLaunch: {
                didRunSuccessHandler = true
            }
        )

        await viewModel.refresh().value
        let group = viewModel.createGroup(containing: apps[1])
        if let task = viewModel.launchApp(appID: apps[1].id, fromGroupID: group.id) {
            await task.value
        }

        #expect(didRunSuccessHandler)
        #expect(viewModel.errorMessage == nil)
    }

    private func makeApp(
        id: String = "com.example.app",
        name: String = "Example"
    ) -> AppItem {
        AppItem(
            id: id,
            name: name,
            bundleIdentifier: id,
            appURL: URL(fileURLWithPath: "/Applications/\(name).app"),
            iconCacheKey: id
        )
    }
}

private struct StubCatalogService: AppCatalogService {
    var apps: [AppItem] = []
    var error: Error?
    var delay: TimeInterval = 0

    func installedApps() throws -> [AppItem] {
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }

        if let error {
            throw error
        }
        return apps
    }
}

private struct StubLaunchService: AppLaunchService {
    var error: Error?

    func launch(_ app: AppItem) async throws {
        if let error {
            throw error
        }
    }
}

private final class StubCatalogCacheStore: CatalogCacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: AppCatalogSnapshot?
    private(set) var savedSnapshots: [AppCatalogSnapshot] = []

    init(snapshot: AppCatalogSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func loadCatalogSnapshot() throws -> AppCatalogSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        return snapshot
    }

    func saveCatalogSnapshot(_ snapshot: AppCatalogSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }

        savedSnapshots.append(snapshot)
        self.snapshot = snapshot
    }
}

private final class StubLayoutStore: LayoutStore {
    var layoutToLoad: LauncherLayout?
    var loadError: Error?
    var saveError: Error?
    private(set) var savedLayouts: [LauncherLayout] = []

    init(
        layoutToLoad: LauncherLayout? = nil,
        loadError: Error? = nil,
        saveError: Error? = nil
    ) {
        self.layoutToLoad = layoutToLoad
        self.loadError = loadError
        self.saveError = saveError
    }

    func loadLayout() throws -> LauncherLayout? {
        if let loadError {
            throw loadError
        }
        return layoutToLoad
    }

    func saveLayout(_ layout: LauncherLayout) throws {
        if let saveError {
            throw saveError
        }
        savedLayouts.append(layout)
        layoutToLoad = layout
    }
}

private enum StubError: Error {
    case failed
}
