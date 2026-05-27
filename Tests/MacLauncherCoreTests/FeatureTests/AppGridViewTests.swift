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

    @Test
    func estimatedColumnCountUsesFixedConfiguration() {
        let configuration = LauncherGridConfiguration(
            tileSize: .large,
            columnMode: .fixed,
            fixedColumnCount: 6
        )

        #expect(AppGridView.estimatedColumnCount(for: 160, configuration: configuration) == 6)
    }

    @Test
    func edgeAutoScrollDisablesWhileSuspended() {
        #expect(AppGridView.allowsEdgeAutoScroll(draggedAppID: "app", isSuspended: false))
        #expect(AppGridView.allowsEdgeAutoScroll(draggedAppID: nil, isSuspended: false) == false)
        #expect(AppGridView.allowsEdgeAutoScroll(draggedAppID: "app", isSuspended: true) == false)
    }

    @Test
    func topEdgeScrollDelaysWhenGroupsExist() {
        #expect(AppGridView.topEdgeScrollDelayNanoseconds(hasGroups: false) == 0)
        #expect(AppGridView.topEdgeScrollDelayNanoseconds(hasGroups: true) == 900_000_000)
    }

    @Test
    func topEdgeScrollZoneShrinksWhenGroupsExist() {
        #expect(AppGridView.topEdgeScrollZoneHeight(hasGroups: false) == 52)
        #expect(AppGridView.topEdgeScrollZoneHeight(hasGroups: true) == 16)
    }
}
