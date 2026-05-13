@MainActor
public protocol AppLaunchService {
    func launch(_ app: AppItem) async throws
}
