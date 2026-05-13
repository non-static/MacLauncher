public protocol LayoutStore {
    func loadLayout() throws -> LauncherLayout?
    func saveLayout(_ layout: LauncherLayout) throws
}
