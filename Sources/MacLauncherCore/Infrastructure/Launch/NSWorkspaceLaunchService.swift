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
    private let delayedCompletionGracePeriodNanoseconds: UInt64

    public init(
        workspace: NSWorkspace = .shared,
        delayedCompletionGracePeriodNanoseconds: UInt64 = 350_000_000
    ) {
        self.workspace = workspace
        self.delayedCompletionGracePeriodNanoseconds = delayedCompletionGracePeriodNanoseconds
    }

    public func launch(_ app: AppItem) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let delayedCompletionGracePeriodNanoseconds = delayedCompletionGracePeriodNanoseconds

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion = LaunchCompletion(continuation: continuation)

            workspace.openApplication(at: app.appURL, configuration: configuration) { _, error in
                if let error {
                    completion.resume(throwing: error)
                } else {
                    completion.resume()
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: delayedCompletionGracePeriodNanoseconds)
                completion.resume()
            }
        }
    }
}

private final class LaunchCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume() {
        guard let continuation = takeContinuation() else { return }
        continuation.resume(returning: ())
    }

    func resume(throwing error: Error) {
        guard let continuation = takeContinuation() else { return }
        continuation.resume(throwing: error)
    }

    private func takeContinuation() -> CheckedContinuation<Void, Error>? {
        lock.lock()
        defer { lock.unlock() }

        let continuation = continuation
        self.continuation = nil
        return continuation
    }
}
