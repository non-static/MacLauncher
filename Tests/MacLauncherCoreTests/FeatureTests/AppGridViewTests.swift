@testable import MacLauncherCore
import Testing

@MainActor
struct AppGridViewTests {
    @Test
    func estimatedColumnCountTracksAvailableWidth() {
        #expect(AppGridView.estimatedColumnCount(for: 160) == 1)
        #expect(AppGridView.estimatedColumnCount(for: 308) == 2)
        #expect(AppGridView.estimatedColumnCount(for: 568) == 4)
    }
}
