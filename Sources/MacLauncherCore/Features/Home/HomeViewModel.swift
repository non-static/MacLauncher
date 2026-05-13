import Combine
import Foundation

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var apps: [AppItem] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    private let catalogService: any AppCatalogService
    private let launchService: any AppLaunchService
    private let onSuccessfulLaunch: @MainActor () -> Void

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
            apps = try catalogService.installedApps()
            errorMessage = nil
        } catch {
            errorMessage = "Could not refresh apps: \(error.localizedDescription)"
        }
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
}
