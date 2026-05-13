public struct AppContainer {
    public let catalogService: any AppCatalogService
    public let launchService: any AppLaunchService
    public let iconLoader: any AppIconLoading

    public init(
        catalogService: any AppCatalogService,
        launchService: any AppLaunchService,
        iconLoader: any AppIconLoading
    ) {
        self.catalogService = catalogService
        self.launchService = launchService
        self.iconLoader = iconLoader
    }

    @MainActor
    public static func live() -> AppContainer {
        AppContainer(
            catalogService: NSWorkspaceCatalogService(),
            launchService: NSWorkspaceLaunchService(),
            iconLoader: NSWorkspaceAppIconLoader()
        )
    }
}
