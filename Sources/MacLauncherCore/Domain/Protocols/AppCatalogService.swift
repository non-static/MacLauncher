public protocol AppCatalogService: Sendable {
    func installedApps() throws -> [AppItem]
}
