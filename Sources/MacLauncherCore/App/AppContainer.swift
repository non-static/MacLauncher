public struct AppContainer {
    public let catalogService: any AppCatalogService
    public let launchService: any AppLaunchService
    public let iconLoader: any AppIconLoading
    public let layoutStore: any LayoutStore
    public let catalogCacheStore: any CatalogCacheStore

    public init(
        catalogService: any AppCatalogService,
        launchService: any AppLaunchService,
        iconLoader: any AppIconLoading,
        layoutStore: any LayoutStore,
        catalogCacheStore: any CatalogCacheStore
    ) {
        self.catalogService = catalogService
        self.launchService = launchService
        self.iconLoader = iconLoader
        self.layoutStore = layoutStore
        self.catalogCacheStore = catalogCacheStore
    }

    @MainActor
    public static func live() -> AppContainer {
        AppContainer(
            catalogService: NSWorkspaceCatalogService(),
            launchService: NSWorkspaceLaunchService(),
            iconLoader: NSWorkspaceAppIconLoader(),
            layoutStore: JSONLayoutStore(),
            catalogCacheStore: JSONCatalogCacheStore()
        )
    }
}
