import AppKit
import SwiftUI

public struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel
    private let iconLoader: any AppIconLoading
    private let backgroundTransparencyPercent: Double
    private let onOpenSettings: () -> Void
    private let onRegisterEscapeHandler: (@escaping @MainActor () -> Bool) -> Void
    private let onUnregisterEscapeHandler: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var navigationColumnCount = 1

    public init(
        viewModel: HomeViewModel,
        iconLoader: any AppIconLoading,
        backgroundTransparencyPercent: Double,
        onOpenSettings: @escaping () -> Void,
        onRegisterEscapeHandler: @escaping (@escaping @MainActor () -> Bool) -> Void = { _ in },
        onUnregisterEscapeHandler: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.iconLoader = iconLoader
        self.backgroundTransparencyPercent = backgroundTransparencyPercent
        self.onOpenSettings = onOpenSettings
        self.onRegisterEscapeHandler = onRegisterEscapeHandler
        self.onUnregisterEscapeHandler = onUnregisterEscapeHandler
    }

    public var body: some View {
        ZStack {
            LauncherBackgroundView(
                transparencyPercent: backgroundTransparencyPercent
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                content
                Divider()
                footer
            }
        }
        .onAppear {
            if viewModel.totalAppCount == 0 {
                viewModel.refresh()
            }
            DispatchQueue.main.async {
                isSearchFocused = true
            }
            onRegisterEscapeHandler {
                let didReset = viewModel.resetSearchToLoadedState()
                if didReset {
                    isSearchFocused = true
                }
                return didReset
            }
        }
        .onDisappear {
            onUnregisterEscapeHandler()
        }
        .background(
            LauncherKeyboardMonitor(
                rowStride: navigationColumnCount,
                onMove: { offset in
                    viewModel.moveSelection(by: offset)
                    isSearchFocused = true
                },
                onLaunchSelected: {
                    viewModel.launchSelected()
                }
            )
        )
        .onMoveCommand { direction in
            switch direction {
            case .left:
                viewModel.moveSelection(by: -1)
            case .right:
                viewModel.moveSelection(by: 1)
            case .up:
                viewModel.moveSelection(by: -navigationColumnCount)
            case .down:
                viewModel.moveSelection(by: navigationColumnCount)
            @unknown default:
                break
            }
            isSearchFocused = true
        }
        .alert(
            "Launcher Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MacLauncher")
                    .font(.title2.weight(.semibold))
                Text(appCountSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(width: 180, alignment: .leading)

            searchField

            Spacer(minLength: 8)

            layoutMenu

            Button {
                onOpenSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button {
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var appCountSummary: String {
        if viewModel.hiddenAppCount > 0 {
            return "\(viewModel.apps.count) of \(viewModel.totalAppCount) apps, \(viewModel.hiddenAppCount) hidden"
        }
        return "\(viewModel.apps.count) of \(viewModel.totalAppCount) apps"
    }

    private var layoutMenu: some View {
        Menu {
            Button("Move Earlier") {
                viewModel.moveSelectedAppInLayout(by: -1)
            }
            .disabled(viewModel.selectedApp == nil)

            Button("Move Later") {
                viewModel.moveSelectedAppInLayout(by: 1)
            }
            .disabled(viewModel.selectedApp == nil)

            Divider()

            Button("Hide Selected App") {
                viewModel.hideSelectedApp()
            }
            .disabled(viewModel.selectedApp == nil)

            Divider()

            Button("Reset Layout", role: .destructive) {
                viewModel.resetLayout()
            }
        } label: {
            Label("Layout", systemImage: "square.grid.3x3")
        }
        .help("Layout")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    viewModel.launchSelected()
                }

            if viewModel.searchQuery.isEmpty == false {
                Button {
                    viewModel.searchQuery = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 240, maxWidth: 360)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var footer: some View {
        ZStack {
            Text("Command-, opens Settings")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Link(destination: LauncherMetadata.githubURL) {
                    Text("\(LauncherMetadata.versionDisplay) GitHub")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .help("Open MacLauncher on GitHub")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.apps.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.apps.isEmpty {
            ContentUnavailableView(
                emptyStateTitle,
                systemImage: emptyStateSystemImage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AppGridView(
                apps: viewModel.apps,
                iconLoader: iconLoader,
                selectedAppID: viewModel.selectedAppID,
                onLaunch: { app in
                    viewModel.launch(app)
                },
                onHide: { app in
                    viewModel.hideApp(app)
                },
                onMoveInLayout: { app, offset in
                    viewModel.moveAppInLayout(app, by: offset)
                },
                onReorder: { draggedAppID, targetIndex in
                    viewModel.reorderAppInLayout(
                        draggedAppID: draggedAppID,
                        targetIndex: targetIndex
                    )
                },
                onColumnCountChange: { columnCount in
                    navigationColumnCount = columnCount
                }
            )
        }
    }

    private var emptyStateTitle: String {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No Applications Found"
            : "No Matching Apps"
    }

    private var emptyStateSystemImage: String {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "app.dashed"
            : "magnifyingglass"
    }
}

private enum LauncherMetadata {
    static let githubURL = URL(string: "https://github.com/non-static/MacLauncher")!
    private static let fallbackVersion = "0.0.1"

    static var versionDisplay: String {
        if let bundleVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String, bundleVersion.isEmpty == false {
            return "v\(bundleVersion)"
        }

        return "v\(fallbackVersion)"
    }
}

private struct LauncherKeyboardMonitor: NSViewRepresentable {
    let rowStride: Int
    let onMove: (Int) -> Void
    let onLaunchSelected: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = KeyboardMonitorView()
        view.coordinator = context.coordinator
        context.coordinator.windowNumber = view.window?.windowNumber
        context.coordinator.rowStride = max(1, rowStride)
        context.coordinator.onMove = onMove
        context.coordinator.onLaunchSelected = onLaunchSelected
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyboardMonitorView {
            view.coordinator = context.coordinator
            context.coordinator.windowNumber = view.window?.windowNumber
        }
        context.coordinator.rowStride = max(1, rowStride)
        context.coordinator.onMove = onMove
        context.coordinator.onLaunchSelected = onLaunchSelected
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var windowNumber: Int?
        var rowStride = 1
        var onMove: ((Int) -> Void)?
        var onLaunchSelected: (() -> Void)?

        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let windowNumber, event.windowNumber == windowNumber else {
                return event
            }

            let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard event.modifierFlags.intersection(blockedModifiers).isEmpty else {
                return event
            }

            switch event.keyCode {
            case 36, 76:
                onLaunchSelected?()
                return nil
            case 123:
                onMove?(-1)
                return nil
            case 124:
                onMove?(1)
                return nil
            case 125:
                onMove?(rowStride)
                return nil
            case 126:
                onMove?(-rowStride)
                return nil
            default:
                return event
            }
        }
    }
}

private final class KeyboardMonitorView: NSView {
    weak var coordinator: LauncherKeyboardMonitor.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.windowNumber = window?.windowNumber
    }
}

private struct LauncherBackgroundView: View {
    let transparencyPercent: Double

    private var opacity: Double {
        let clamped = min(max(transparencyPercent, 0), 100)
        return (100 - clamped) / 100
    }

    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor).opacity(0.9),
                        Color(nsColor: .controlBackgroundColor).opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(opacity)
    }
}
