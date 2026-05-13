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

private enum StubError: Error {
    case failed
}
