import Foundation
@testable import MacLauncherCore
import Testing

struct LauncherLayoutTests {
    @Test
    func codableRoundTrip() throws {
        let group = AppGroup(
            id: try #require(UUID(uuidString: "1F0C6C6D-0A81-44D3-B7A2-5E6B46C1B7F8")),
            name: "Work",
            appIDs: ["com.example.mail"]
        )
        let layout = LauncherLayout(
            orderedAppIDs: ["com.example.mail"],
            groups: [group],
            hiddenAppIDs: ["com.example.hidden"],
            version: 1
        )

        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(LauncherLayout.self, from: data)

        #expect(decoded == layout)
    }
}
