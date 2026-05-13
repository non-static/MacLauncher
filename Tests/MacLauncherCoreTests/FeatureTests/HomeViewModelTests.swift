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
    func launch(_ app: AppItem) async throws {}
}

private enum StubError: Error {
    case failed
}
