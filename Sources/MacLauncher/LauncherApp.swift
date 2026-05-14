import AppKit
import MacLauncherCore
import SwiftUI

@main
struct MacLauncherApp: App {
    @NSApplicationDelegateAdaptor(LauncherAppDelegate.self) private var appDelegate

    private let container: AppContainer

    @AppStorage("backgroundTransparencyPercent") private var backgroundTransparencyPercent = 30.0

    @StateObject private var viewModel: HomeViewModel

    init() {
        let container = AppContainer.live()
        self.container = container
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                catalogService: container.catalogService,
                launchService: container.launchService,
                layoutStore: container.layoutStore,
                onSuccessfulLaunch: {
                    NSApp.terminate(nil)
                }
            )
        )
    }

    var body: some Scene {
        WindowGroup("MacLauncher") {
            LauncherRootView(
                viewModel: viewModel,
                iconLoader: container.iconLoader,
                backgroundTransparencyPercent: backgroundTransparencyPercent,
                appDelegate: appDelegate
            )
            .frame(width: 860, height: 620)
            .background(WindowTransparencyConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(
                backgroundTransparencyPercent: $backgroundTransparencyPercent
            )
            .frame(width: 420)
            .background(SettingsWindowConfigurator())
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Apps") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .windowSize) {}
        }
    }
}

private struct LauncherRootView: View {
    @Environment(\.openSettings) private var openSettings

    let viewModel: HomeViewModel
    let iconLoader: any AppIconLoading
    let backgroundTransparencyPercent: Double
    let appDelegate: LauncherAppDelegate

    var body: some View {
        HomeView(
            viewModel: viewModel,
            iconLoader: iconLoader,
            backgroundTransparencyPercent: backgroundTransparencyPercent,
            onOpenSettings: {
                openSettings()
            },
            onRegisterEscapeHandler: { handler in
                appDelegate.launcherEscapeHandler = handler
            },
            onUnregisterEscapeHandler: {
                appDelegate.launcherEscapeHandler = nil
            }
        )
    }
}
