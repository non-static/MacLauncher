public protocol SearchIndex {
    func replaceAll(with apps: [AppItem])
    func search(_ query: String) -> [AppItem]
}
