import MacLauncherCore
import SwiftUI

@main
struct MacLauncherApp: App {
    @NSApplicationDelegateAdaptor(LauncherAppDelegate.self) private var appDelegate

    private let container: AppContainer

    @StateObject private var viewModel: HomeViewModel

    init() {
        let container = AppContainer.live()
        self.container = container
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                catalogService: container.catalogService,
                launchService: container.launchService
            )
        )
    }

    var body: some Scene {
        WindowGroup("MacLauncher") {
            HomeView(
                viewModel: viewModel,
                iconLoader: container.iconLoader
            )
            .frame(minWidth: 720, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Apps") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
