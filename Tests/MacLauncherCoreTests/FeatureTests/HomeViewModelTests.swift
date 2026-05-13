import Foundation
@testable import MacLauncherCore
import Testing

@MainActor
struct HomeViewModelTests {
    @Test
    func refreshLoadsApps() {
        let app = AppItem(
            id: "com.example.app",
            name: "Example",
            bundleIdentifier: "com.example.app",
            appURL: URL(fileURLWithPath: "/Applications/Example.app"),
            iconCacheKey: "com.example.app"
        )
        let viewModel = HomeViewModel(
            catalogService: StubCatalogService(apps: [app]),
            launchService: StubLaunchService()
        )

        viewModel.refresh()

        #expect(viewModel.apps == [app])
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

    private func makeApp() -> AppItem {
        AppItem(
            id: "com.example.app",
            name: "Example",
            bundleIdentifier: "com.example.app",
            appURL: URL(fileURLWithPath: "/Applications/Example.app"),
            iconCacheKey: "com.example.app"
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
