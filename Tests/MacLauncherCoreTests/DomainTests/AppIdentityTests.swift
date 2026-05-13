import Foundation
@testable import MacLauncherCore
import Testing

struct AppIdentityTests {
    @Test
    func bundleIdentifierIsPreferredID() {
        let url = URL(fileURLWithPath: "/Applications/Example.app")

        let id = AppIdentity.makeID(
            bundleIdentifier: "com.example.app",
            appURL: url
        )

        #expect(id == "com.example.app")
    }

    @Test
    func pathFallbackIsCanonicalized() {
        let url = URL(fileURLWithPath: "/Applications/../Applications/Example.app")

        let id = AppIdentity.makeID(bundleIdentifier: nil, appURL: url)

        #expect(id == "/Applications/Example.app")
    }

    @Test
    func stableHashIsDeterministic() {
        let first = StableHash.fnv1a64Hex("mac-launcher")
        let second = StableHash.fnv1a64Hex("mac-launcher")

        #expect(first == second)
    }
}
