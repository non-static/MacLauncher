public protocol CatalogCacheStore: Sendable {
    func loadCatalogSnapshot() throws -> AppCatalogSnapshot?
    func saveCatalogSnapshot(_ snapshot: AppCatalogSnapshot) throws
}
