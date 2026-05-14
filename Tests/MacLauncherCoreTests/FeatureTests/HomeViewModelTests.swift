import Foundation
@testable import MacLauncherCore
import Testing

@MainActor
struct HomeViewModelTests {
    @Test
    func refreshLoadsApps() {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService()
        )

        viewModel.refresh()

        #expect(viewModel.apps == [app])
        #expect(viewModel.totalAppCount == 1)
        #expect(viewModel.selectedAppID == app.id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func refreshFailureSetsError() {
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(error: StubError.failed),
            launchService: StubLaunchService()
        )

        viewModel.refresh()

        #expect(viewModel.apps.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func refreshAppliesPersistedOrderAndHiddenApps() {
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

        viewModel.refresh()

        #expect(viewModel.apps == [apps[1], apps[0]])
        #expect(viewModel.totalAppCount == 2)
        #expect(viewModel.hiddenAppCount == 1)
        #expect(viewModel.selectedAppID == apps[1].id)
    }

    @Test
    func hideAppPersistsLayoutAndRemovesAppFromGrid() {
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

        viewModel.refresh()
        viewModel.hideApp(apps[1])

        #expect(viewModel.apps == [apps[0], apps[2]])
        #expect(viewModel.hiddenAppCount == 1)
        #expect(store.savedLayouts.last?.hiddenAppIDs == [apps[1].id])
    }

    @Test
    func createGroupFromSelectedAppPersistsGroupAndRemovesAppFromGrid() throws {
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

        viewModel.refresh()
        viewModel.moveSelection(by: 1)
        let group = try #require(viewModel.createGroupFromSelectedApp())

        #expect(group.name == "New Group")
        #expect(viewModel.groups == [group])
        #expect(viewModel.apps == [apps[0], apps[2]])
        #expect(viewModel.apps(inGroupID: group.id) == [apps[1]])
        #expect(store.savedLayouts.last?.groups == [group])
    }

    @Test
    func moveAppIntoAndOutOfGroupPersistsMembership() throws {
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

        viewModel.refresh()
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
    func moveAppIDToGroupSupportsDropWithoutOpeningGroup() {
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

        viewModel.refresh()
        let group = viewModel.createGroup(containing: apps[0])
        viewModel.moveApp(appID: apps[1].id, toGroup: group.id)

        #expect(viewModel.apps.isEmpty)
        #expect(viewModel.apps(inGroupID: group.id) == apps)
        #expect(store.savedLayouts.last?.groups.first?.appIDs == apps.map(\.id))
    }

    @Test
    func renameGroupPersistsTrimmedUniqueName() throws {
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

        viewModel.refresh()
        let firstGroup = viewModel.createGroup(containing: apps[0])
        _ = viewModel.createGroup(containing: apps[1])
        viewModel.renameGroup(groupID: firstGroup.id, name: "  New Group 2  ")

        #expect(viewModel.group(for: firstGroup.id)?.name == "New Group 2 2")
        #expect(store.savedLayouts.last?.groups.first?.name == "New Group 2 2")
    }

    @Test
    func deleteGroupRestoresGroupedAppsToGrid() {
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

        viewModel.refresh()
        let group = viewModel.createGroup(containing: apps[0])
        viewModel.deleteGroup(groupID: group.id)

        #expect(viewModel.groups.isEmpty)
        #expect(viewModel.apps == apps)
        #expect(store.savedLayouts.last?.groups.isEmpty == true)
    }

    @Test
    func refreshAppliesPersistedGroups() throws {
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

        viewModel.refresh()

        #expect(viewModel.groups == [group])
        #expect(viewModel.apps == [apps[0], apps[2]])
        #expect(viewModel.apps(inGroupID: group.id) == [apps[1]])
    }

    @Test
    func moveAppInLayoutPersistsCustomOrder() {
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

        viewModel.refresh()
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
    func reorderAppInLayoutPersistsDroppedOrder() {
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

        viewModel.refresh()
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
    func reorderAppInLayoutSurvivesRefreshFromStore() {
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
        firstViewModel.refresh()
        firstViewModel.reorderAppInLayout(draggedAppID: apps[2].id, targetAppID: apps[0].id)

        let secondViewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService(),
            layoutStore: store
        )
        secondViewModel.refresh()

        #expect(secondViewModel.apps == [apps[2], apps[0], apps[1]])
    }

    @Test
    func reorderAppInLayoutCanMoveAppToFirstIndex() {
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

        viewModel.refresh()
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
    func reorderAppInLayoutCanMoveAppAfterLastIndex() {
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

        viewModel.refresh()
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
    func reorderAppInLayoutRejectsInvalidDropWithoutSaving() {
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

        viewModel.refresh()
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
    func resetLayoutRestoresScannedOrderAndHiddenApps() {
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

        viewModel.refresh()
        viewModel.resetLayout()

        #expect(viewModel.apps == apps)
        #expect(viewModel.hiddenAppCount == 0)
        #expect(store.savedLayouts.last == LauncherLayout(orderedAppIDs: apps.map(\.id)))
    }

    @Test
    func loadLayoutFailureFallsBackToScannedApps() {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService(),
            layoutStore: StubLayoutStore(loadError: StubError.failed)
        )

        viewModel.refresh()

        #expect(viewModel.apps == [app])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func unsupportedLayoutVersionFallsBackToScannedApps() {
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

        viewModel.refresh()

        #expect(viewModel.apps == apps)
        #expect(viewModel.hiddenAppCount == 0)
    }

    @Test
    func searchFiltersAppsByNameAndClearRestoresAllApps() {
        let apps = [
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal"),
            makeApp(id: "com.example.preview", name: "Preview")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        viewModel.refresh()
        viewModel.searchQuery = "TER"

        #expect(viewModel.apps == [apps[1]])
        #expect(viewModel.selectedAppID == apps[1].id)

        viewModel.searchQuery = ""

        #expect(viewModel.apps == apps)
        #expect(viewModel.totalAppCount == 3)
    }

    @Test
    func selectionMovesWithinVisibleApps() {
        let apps = [
            makeApp(id: "com.example.one", name: "One"),
            makeApp(id: "com.example.two", name: "Two"),
            makeApp(id: "com.example.three", name: "Three")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        viewModel.refresh()
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedAppID == apps[1].id)

        viewModel.moveSelection(by: 10)
        #expect(viewModel.selectedAppID == apps[2].id)

        viewModel.moveSelection(by: -10)
        #expect(viewModel.selectedAppID == apps[0].id)
    }

    @Test
    func searchReconcilesSelectionToVisibleApps() {
        let apps = [
            makeApp(id: "com.example.calendar", name: "Calendar"),
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        viewModel.refresh()
        viewModel.moveSelection(by: 2)
        viewModel.searchQuery = "saf"

        #expect(viewModel.apps == [apps[1]])
        #expect(viewModel.selectedAppID == apps[1].id)
    }

    @Test
    func resetSearchToLoadedStateClearsQueryAndSelectsFirstApp() {
        let apps = [
            makeApp(id: "com.example.safari", name: "Safari"),
            makeApp(id: "com.example.terminal", name: "Terminal"),
            makeApp(id: "com.example.preview", name: "Preview")
        ]
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: apps),
            launchService: StubLaunchService()
        )

        viewModel.refresh()
        viewModel.moveSelection(by: 2)
        viewModel.searchQuery = "ter"

        let didReset = viewModel.resetSearchToLoadedState()

        #expect(didReset)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.apps == apps)
        #expect(viewModel.selectedAppID == apps[0].id)
    }

    @Test
    func resetSearchToLoadedStateReturnsFalseWhenQueryIsEmpty() {
        let app = makeApp()
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService()
        )

        viewModel.refresh()

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

        viewModel.refresh()
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

        viewModel.refresh()
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

    func installedApps() throws -> [AppItem] {
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
