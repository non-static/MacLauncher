import AppKit

public enum AppLaunchError: LocalizedError {
    case failedToLaunch(URL)

    public var errorDescription: String? {
        switch self {
        case let .failedToLaunch(url):
            "Could not launch \(url.path)"
        }
    }
}

public final class NSWorkspaceLaunchService: AppLaunchService {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func launch(_ app: AppItem) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.openApplication(at: app.appURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
