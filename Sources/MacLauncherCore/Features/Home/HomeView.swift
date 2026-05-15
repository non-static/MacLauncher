import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel
    private let iconLoader: any AppIconLoading
    private let backgroundTransparencyPercent: Double
    private let displayLoadTimeInMilliseconds: Bool
    private let onOpenSettings: () -> Void
    private let onRegisterEscapeHandler: (@escaping @MainActor () -> Bool) -> Void
    private let onUnregisterEscapeHandler: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var navigationColumnCount = 1
    @State private var openedGroupID: AppGroup.ID?

    public init(
        viewModel: HomeViewModel,
        iconLoader: any AppIconLoading,
        backgroundTransparencyPercent: Double,
        displayLoadTimeInMilliseconds: Bool,
        onOpenSettings: @escaping () -> Void,
        onRegisterEscapeHandler: @escaping (@escaping @MainActor () -> Bool) -> Void = { _ in },
        onUnregisterEscapeHandler: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.iconLoader = iconLoader
        self.backgroundTransparencyPercent = backgroundTransparencyPercent
        self.displayLoadTimeInMilliseconds = displayLoadTimeInMilliseconds
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

            if let openedGroupID {
                groupOverlay(groupID: openedGroupID)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
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
                if openedGroupID != nil {
                    closeGroupPanelAndRestoreFocus()
                    return true
                }

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
                isEnabled: openedGroupID == nil,
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
        if viewModel.isLoading {
            return "Scanning applications..."
        }

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

            Button("New Group from Selected") {
                viewModel.createGroupFromSelectedApp()
            }
            .disabled(viewModel.selectedApp == nil)

            if viewModel.groups.isEmpty == false {
                Menu("Move Selected to Group") {
                    ForEach(viewModel.groups) { group in
                        Button(group.name) {
                            viewModel.moveSelectedAppToGroup(groupID: group.id)
                        }
                    }
                }
                .disabled(viewModel.selectedApp == nil)
            }

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
                if displayLoadTimeInMilliseconds,
                   let loadTimeMilliseconds = viewModel.loadTimeMilliseconds
                {
                    Text("Load \(loadTimeMilliseconds) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Link(destination: LauncherMetadata.githubURL) {
                        Text(LauncherMetadata.versionDisplay)
                    }
                    .help("Open MacLauncher on GitHub")

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Link(destination: LauncherMetadata.commitURL) {
                        Text(LauncherMetadata.commitDisplay)
                    }
                    .help("Open commit \(LauncherMetadata.commitDisplay) on GitHub")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private func groupOverlay(groupID: AppGroup.ID) -> some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    closeGroupPanelAndRestoreFocus()
                }

            GroupPanelView(
                viewModel: viewModel,
                iconLoader: iconLoader,
                groupID: groupID,
                onClose: {
                    closeGroupPanelAndRestoreFocus()
                }
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 24, y: 12)
            .padding(28)
        }
        .animation(.easeInOut(duration: 0.16), value: openedGroupID)
    }

    private func closeGroupPanelAndRestoreFocus() {
        if openedGroupID != nil {
            openedGroupID = nil
        }

        restoreSearchFocusAfterGroupClose()
    }

    private func restoreSearchFocusAfterGroupClose() {
        isSearchFocused = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            NSApp.activate(ignoringOtherApps: true)
            let launcherWindow = NSApp.windows.first { window in
                window.isVisible && window.canBecomeKey
            }
            launcherWindow?.makeKeyAndOrderFront(nil)
            launcherWindow?.makeFirstResponder(nil)
            isSearchFocused = true
        }
    }

    private var isSearchActive: Bool {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.apps.isEmpty && viewModel.groups.isEmpty {
            ProgressView("Scanning Applications...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.apps.isEmpty && viewModel.groups.isEmpty {
            ContentUnavailableView(
                emptyStateTitle,
                systemImage: emptyStateSystemImage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if viewModel.groups.isEmpty == false {
                    GroupShelfView(
                        groups: viewModel.groups,
                        appCount: { group in
                            viewModel.apps(inGroupID: group.id).count
                        },
                        onOpen: { group in
                            openedGroupID = group.id
                        },
                        onDelete: { group in
                            viewModel.deleteGroup(groupID: group.id)
                        },
                        onDropApp: { appID, group in
                            viewModel.moveApp(appID: appID, toGroup: group.id)
                        }
                    )
                    Divider()
                }

                if viewModel.apps.isEmpty {
                    ContentUnavailableView(
                        isSearchActive ? "No Matching Apps" : "No Ungrouped Apps",
                        systemImage: isSearchActive ? "magnifyingglass" : "square.grid.3x3"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppGridView(
                        apps: viewModel.apps,
                        groups: viewModel.groups,
                        iconLoader: iconLoader,
                        selectedAppID: viewModel.selectedAppID,
                        onLaunch: { app in
                            viewModel.launch(app)
                        },
                        onHide: { app in
                            viewModel.hideApp(app)
                        },
                        onCreateGroup: { app in
                            viewModel.createGroup(containing: app)
                        },
                        onMoveToGroup: { app, groupID in
                            viewModel.moveApp(app, toGroup: groupID)
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
            .animation(.easeInOut(duration: 0.16), value: viewModel.apps.map(\.id))
            .animation(.easeInOut(duration: 0.16), value: viewModel.groups.map(\.id))
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

private struct GroupShelfView: View {
    let groups: [AppGroup]
    let appCount: (AppGroup) -> Int
    let onOpen: (AppGroup) -> Void
    let onDelete: (AppGroup) -> Void
    let onDropApp: (AppItem.ID, AppGroup) -> Void

    @State private var targetedGroupID: AppGroup.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(groups) { group in
                    Button {
                        onOpen(group)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)

                            Text(group.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)

                            Text("\(appCount(group)) apps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 132, height: 96, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(borderColor(for: group), lineWidth: targetedGroupID == group.id ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onDrop(
                        of: [UTType.plainText],
                        isTargeted: dropTargetBinding(for: group)
                    ) { providers in
                        loadDroppedAppID(from: providers, into: group)
                    }
                    .contextMenu {
                        Button("Open Group") {
                            onOpen(group)
                        }

                        Button("Delete Group", role: .destructive) {
                            onDelete(group)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(height: 126)
    }

    private func borderColor(for group: AppGroup) -> Color {
        targetedGroupID == group.id ? Color.accentColor : Color.primary.opacity(0.12)
    }

    private func dropTargetBinding(for group: AppGroup) -> Binding<Bool> {
        Binding(
            get: { targetedGroupID == group.id },
            set: { isTargeted in
                targetedGroupID = isTargeted ? group.id : nil
            }
        )
    }

    private func loadDroppedAppID(from providers: [NSItemProvider], into group: AppGroup) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
            guard let appID = Self.appID(from: item) else {
                return
            }

            DispatchQueue.main.async {
                onDropApp(appID, group)
            }
        }
        return true
    }

    nonisolated private static func appID(from item: NSSecureCoding?) -> AppItem.ID? {
        if let appID = item as? String {
            return appID
        }
        if let appID = item as? NSString {
            return appID as String
        }
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

private struct GroupPanelView: View {
    @ObservedObject var viewModel: HomeViewModel

    let iconLoader: any AppIconLoading
    let groupID: AppGroup.ID
    let onClose: () -> Void

    @State private var nameDraft = ""

    private let columns = [
        GridItem(.adaptive(minimum: LauncherDesign.tileMinWidth), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            groupContent
            Divider()
            footer
        }
        .frame(width: 640, height: 500)
        .onAppear {
            syncNameDraft()
        }
    }

    private var group: AppGroup? {
        viewModel.group(for: groupID)
    }

    private var groupApps: [AppItem] {
        viewModel.apps(inGroupID: groupID)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            TextField("Group Name", text: $nameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    saveName()
                }

            Button {
                saveName()
            } label: {
                Label("Rename", systemImage: "checkmark")
            }
            .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark")
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var groupContent: some View {
        if group == nil {
            ContentUnavailableView("Group Not Found", systemImage: "folder.badge.questionmark")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groupApps.isEmpty {
            ContentUnavailableView("No Apps in Group", systemImage: "folder")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(groupApps) { app in
                        Button {
                            viewModel.launchApp(appID: app.id, fromGroupID: groupID)
                        } label: {
                            AppTileView(app: app, iconLoader: iconLoader)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove from Group") {
                                viewModel.removeAppFromGroup(appID: app.id, groupID: groupID)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(groupApps.count) apps")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                viewModel.deleteGroup(groupID: groupID)
                onClose()
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
            .disabled(group == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func syncNameDraft() {
        nameDraft = group?.name ?? ""
    }

    private func saveName() {
        viewModel.renameGroup(groupID: groupID, name: nameDraft)
        syncNameDraft()
    }
}

private enum LauncherMetadata {
    static let githubURL = URL(string: "https://github.com/non-static/MacLauncher")!
    private static let fallbackVersion = "0.0.2"
    private static let commitInfoKey = "MacLauncherGitCommit"
    private static let resolvedCommitID = resolveCommitID()

    static var versionDisplay: String {
        if let bundleVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String, bundleVersion.isEmpty == false {
            return "v\(bundleVersion)"
        }

        return "v\(fallbackVersion)"
    }

    static var commitDisplay: String {
        guard let resolvedCommitID else {
            return "unknown"
        }

        return String(resolvedCommitID.prefix(7))
    }

    static var commitURL: URL {
        guard let resolvedCommitID,
              let url = URL(string: "\(githubURL.absoluteString)/commit/\(resolvedCommitID)")
        else {
            return githubURL
        }

        return url
    }

    private static func resolveCommitID() -> String? {
        if let bundledCommit = Bundle.main.object(
            forInfoDictionaryKey: commitInfoKey
        ) as? String, let normalizedCommit = normalizeCommitID(bundledCommit) {
            return normalizedCommit
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let commitID = gitCommitID(in: currentDirectory) {
            return commitID
        }

        return sourceRepositoryDirectory().flatMap(gitCommitID(in:))
    }

    private static func normalizeCommitID(_ commitID: String) -> String? {
        let trimmedCommitID = commitID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommitID.isEmpty == false else {
            return nil
        }

        return trimmedCommitID
    }

    private static func sourceRepositoryDirectory() -> URL? {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(".git", isDirectory: true).path
            ) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        return nil
    }

    private static func gitCommitID(in repositoryDirectory: URL) -> String? {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "git",
            "-C",
            repositoryDirectory.path,
            "rev-parse",
            "HEAD"
        ]
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)
        return output.flatMap(normalizeCommitID(_:))
    }
}

private struct LauncherKeyboardMonitor: NSViewRepresentable {
    let isEnabled: Bool
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
        context.coordinator.isEnabled = isEnabled
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
        context.coordinator.isEnabled = isEnabled
        context.coordinator.rowStride = max(1, rowStride)
        context.coordinator.onMove = onMove
        context.coordinator.onLaunchSelected = onLaunchSelected
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var windowNumber: Int?
        var isEnabled = true
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
            guard isEnabled else {
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
