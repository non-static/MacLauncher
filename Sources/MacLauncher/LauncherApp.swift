import AppKit
import MacLauncherCore
import SwiftUI

@main
struct MacLauncherApp: App {
    @NSApplicationDelegateAdaptor(LauncherAppDelegate.self) private var appDelegate

    private let container: AppContainer

    @AppStorage("backgroundTransparencyPercent") private var backgroundTransparencyPercent = 30.0
    @AppStorage("displayLoadTimeInMilliseconds") private var displayLoadTimeInMilliseconds = false
    @AppStorage("showsSystemApps") private var showsSystemApps = true
    @AppStorage("showsHiddenApps") private var showsHiddenApps = false
    @AppStorage("tileSize") private var tileSizeRaw = LauncherTileSize.medium.rawValue
    @AppStorage("columnMode") private var columnModeRaw = LauncherColumnMode.adaptive.rawValue
    @AppStorage("fixedColumnCount") private var fixedColumnCount = 5
    @AppStorage("startsAtLogin") private var startsAtLogin = false
    @AppStorage("hotkey") private var hotkeyRaw = LauncherHotkeyOption.none.rawValue

    @State private var settingsErrorMessage: String?

    @StateObject private var viewModel: HomeViewModel

    init() {
        let container = AppContainer.live()
        self.container = container
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                catalogService: container.catalogService,
                launchService: container.launchService,
                layoutStore: container.layoutStore,
                catalogCacheStore: container.catalogCacheStore,
                onSuccessfulLaunch: {
                    LauncherAppDelegate.terminateAfterSuccessfulLaunch()
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
                displayLoadTimeInMilliseconds: displayLoadTimeInMilliseconds,
                showsSystemApps: showsSystemApps,
                showsHiddenApps: showsHiddenApps,
                gridConfiguration: gridConfiguration,
                appDelegate: appDelegate
            )
            .frame(width: 860, height: 620)
            .background(WindowTransparencyConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(
                backgroundTransparencyPercent: $backgroundTransparencyPercent,
                displayLoadTimeInMilliseconds: $displayLoadTimeInMilliseconds,
                showsSystemApps: $showsSystemApps,
                showsHiddenApps: $showsHiddenApps,
                tileSize: tileSizeBinding,
                columnMode: columnModeBinding,
                fixedColumnCount: fixedColumnCountBinding,
                startsAtLogin: startsAtLoginBinding,
                hotkey: hotkeyBinding,
                onResetLayout: {
                    viewModel.resetLayout()
                }
            )
            .frame(width: 420)
            .background(SettingsWindowConfigurator())
            .alert(
                "Settings Error",
                isPresented: Binding(
                    get: { settingsErrorMessage != nil },
                    set: { isPresented in
                        if isPresented == false {
                            settingsErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    settingsErrorMessage = nil
                }
            } message: {
                Text(settingsErrorMessage ?? "")
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Apps") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                if let hotkeyShortcut {
                    Button("Focus Launcher") {
                        LauncherAppDelegate.focusLauncherWindow()
                    }
                    .keyboardShortcut(hotkeyShortcut.key, modifiers: hotkeyShortcut.modifiers)
                }
            }
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .windowSize) {}
        }
    }

    private var gridConfiguration: LauncherGridConfiguration {
        LauncherGridConfiguration(
            tileSize: tileSize,
            columnMode: columnMode,
            fixedColumnCount: fixedColumnCount
        )
    }

    private var tileSize: LauncherTileSize {
        LauncherTileSize(rawValue: tileSizeRaw) ?? .medium
    }

    private var columnMode: LauncherColumnMode {
        LauncherColumnMode(rawValue: columnModeRaw) ?? .adaptive
    }

    private var hotkey: LauncherHotkeyOption {
        LauncherHotkeyOption(rawValue: hotkeyRaw) ?? .none
    }

    private var tileSizeBinding: Binding<LauncherTileSize> {
        Binding(
            get: { tileSize },
            set: { tileSizeRaw = $0.rawValue }
        )
    }

    private var columnModeBinding: Binding<LauncherColumnMode> {
        Binding(
            get: { columnMode },
            set: { columnModeRaw = $0.rawValue }
        )
    }

    private var fixedColumnCountBinding: Binding<Int> {
        Binding(
            get: { fixedColumnCount },
            set: { fixedColumnCount = min(max($0, 2), 8) }
        )
    }

    private var startsAtLoginBinding: Binding<Bool> {
        Binding(
            get: { startsAtLogin },
            set: { requestedValue in
                let previousValue = startsAtLogin
                startsAtLogin = requestedValue

                do {
                    try LaunchAtLoginController.setEnabled(requestedValue)
                } catch {
                    startsAtLogin = previousValue
                    settingsErrorMessage = error.localizedDescription
                }
            }
        )
    }

    private var hotkeyBinding: Binding<LauncherHotkeyOption> {
        Binding(
            get: { hotkey },
            set: { hotkeyRaw = $0.rawValue }
        )
    }

    private var hotkeyShortcut: (key: KeyEquivalent, modifiers: EventModifiers)? {
        switch hotkey {
        case .none:
            nil
        case .commandShiftSpace:
            (KeyEquivalent(" "), [.command, .shift])
        case .optionSpace:
            (KeyEquivalent(" "), [.option])
        case .controlSpace:
            (KeyEquivalent(" "), [.control])
        }
    }
}

private struct LauncherRootView: View {
    @Environment(\.openSettings) private var openSettings

    let viewModel: HomeViewModel
    let iconLoader: any AppIconLoading
    let backgroundTransparencyPercent: Double
    let displayLoadTimeInMilliseconds: Bool
    let showsSystemApps: Bool
    let showsHiddenApps: Bool
    let gridConfiguration: LauncherGridConfiguration
    let appDelegate: LauncherAppDelegate

    var body: some View {
        HomeView(
            viewModel: viewModel,
            iconLoader: iconLoader,
            backgroundTransparencyPercent: backgroundTransparencyPercent,
            displayLoadTimeInMilliseconds: displayLoadTimeInMilliseconds,
            showsSystemApps: showsSystemApps,
            showsHiddenApps: showsHiddenApps,
            gridConfiguration: gridConfiguration,
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
