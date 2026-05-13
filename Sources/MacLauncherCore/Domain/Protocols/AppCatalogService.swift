public protocol AppCatalogService {
    func installedApps() throws -> [AppItem]
}
