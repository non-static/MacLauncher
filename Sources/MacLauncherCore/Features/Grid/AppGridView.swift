import SwiftUI
import UniformTypeIdentifiers

public struct AppGridView: View {
    private let apps: [AppItem]
    private let iconLoader: any AppIconLoading
    private let selectedAppID: AppItem.ID?
    private let onLaunch: (AppItem) -> Void
    private let onHide: (AppItem) -> Void
    private let onMoveInLayout: (AppItem, Int) -> Void
    private let onReorder: (AppItem.ID, Int) -> Bool
    private let onColumnCountChange: (Int) -> Void

    @State private var draggedAppID: AppItem.ID?
    @State private var dropTarget: AppGridDropTarget?

    private let columns = [
        GridItem(.adaptive(minimum: LauncherDesign.tileMinWidth), spacing: Self.gridSpacing)
    ]

    private static let gridSpacing: CGFloat = 18
    private static let gridPadding: CGFloat = 24

    public init(
        apps: [AppItem],
        iconLoader: any AppIconLoading,
        selectedAppID: AppItem.ID? = nil,
        onLaunch: @escaping (AppItem) -> Void,
        onHide: @escaping (AppItem) -> Void = { _ in },
        onMoveInLayout: @escaping (AppItem, Int) -> Void = { _, _ in },
        onReorder: @escaping (AppItem.ID, Int) -> Bool = { _, _ in false },
        onColumnCountChange: @escaping (Int) -> Void = { _ in }
    ) {
        self.apps = apps
        self.iconLoader = iconLoader
        self.selectedAppID = selectedAppID
        self.onLaunch = onLaunch
        self.onHide = onHide
        self.onMoveInLayout = onMoveInLayout
        self.onReorder = onReorder
        self.onColumnCountChange = onColumnCountChange
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            Button {
                                onLaunch(app)
                            } label: {
                                AppTileView(
                                    app: app,
                                    iconLoader: iconLoader,
                                    isSelected: app.id == selectedAppID,
                                    dropIndicator: dropIndicator(for: app.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .id(app.id)
                            .onDrag {
                                draggedAppID = app.id
                                return NSItemProvider(object: app.id as NSString)
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: AppTileDropDelegate(
                                    app: app,
                                    appIndex: index,
                                    draggedAppID: $draggedAppID,
                                    dropTarget: $dropTarget,
                                    onReorder: onReorder
                                )
                            )
                            .contextMenu {
                                Button("Move Earlier") {
                                    onMoveInLayout(app, -1)
                                }

                                Button("Move Later") {
                                    onMoveInLayout(app, 1)
                                }

                                Divider()

                                Button("Hide App") {
                                    onHide(app)
                                }
                            }
                        }
                    }
                    .padding(Self.gridPadding)
                }
                .onAppear {
                    reportColumnCount(for: geometry.size.width)
                    scrollToSelection(with: proxy)
                }
                .onChange(of: geometry.size.width) { _, width in
                    reportColumnCount(for: width)
                }
                .onChange(of: selectedAppID) { _, _ in
                    scrollToSelection(with: proxy)
                }
                .onChange(of: apps.map(\.id)) { _, _ in
                    reconcileDragState()
                    scrollToSelection(with: proxy)
                }
                .onChange(of: dropTarget) { _, _ in
                    scrollToDropTarget(with: proxy)
                }
            }
        }
    }

    static func estimatedColumnCount(for width: CGFloat) -> Int {
        let contentWidth = max(0, width - (gridPadding * 2))
        let columnWidth = LauncherDesign.tileMinWidth + gridSpacing
        return max(1, Int((contentWidth + gridSpacing) / columnWidth))
    }

    private func reportColumnCount(for width: CGFloat) {
        onColumnCountChange(Self.estimatedColumnCount(for: width))
    }

    private func scrollToSelection(with proxy: ScrollViewProxy) {
        guard let selectedAppID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            proxy.scrollTo(selectedAppID, anchor: .center)
        }
    }

    private func reconcileDragState() {
        let appIDs = Set(apps.map(\.id))
        if let draggedAppID, appIDs.contains(draggedAppID) == false {
            self.draggedAppID = nil
        }
        if let dropTarget, appIDs.contains(dropTarget.appID) == false {
            self.dropTarget = nil
        }
    }

    private func dropIndicator(for appID: AppItem.ID) -> AppTileDropIndicator {
        guard dropTarget?.appID == appID else {
            return .none
        }
        return dropTarget?.indicator ?? .none
    }

    private func scrollToDropTarget(with proxy: ScrollViewProxy) {
        guard let dropTarget else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            proxy.scrollTo(dropTarget.appID, anchor: .center)
        }
    }
}

private struct AppGridDropTarget: Equatable {
    let appID: AppItem.ID
    let insertionIndex: Int
    let indicator: AppTileDropIndicator
}

private struct AppTileDropDelegate: DropDelegate {
    let app: AppItem
    let appIndex: Int

    @Binding var draggedAppID: AppItem.ID?
    @Binding var dropTarget: AppGridDropTarget?

    let onReorder: (AppItem.ID, Int) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedAppID else {
            return false
        }
        return draggedAppID != app.id
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info), let target = target(for: info) else {
            return DropProposal(operation: .cancel)
        }

        dropTarget = target
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info), let target = target(for: info) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.1)) {
            dropTarget = target
        }
    }

    func dropExited(info: DropInfo) {
        guard dropTarget?.appID == app.id else {
            return
        }

        withAnimation(.easeInOut(duration: 0.1)) {
            dropTarget = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedAppID = nil
            dropTarget = nil
        }

        guard let draggedAppID, draggedAppID != app.id, let target = target(for: info) else {
            return false
        }

        return onReorder(draggedAppID, target.insertionIndex)
    }

    private func target(for info: DropInfo) -> AppGridDropTarget? {
        guard let draggedAppID, draggedAppID != app.id else {
            return nil
        }

        let isBeforeTarget = info.location.x < LauncherDesign.tileWidth / 2
        return AppGridDropTarget(
            appID: app.id,
            insertionIndex: isBeforeTarget ? appIndex : appIndex + 1,
            indicator: isBeforeTarget ? .before : .after
        )
    }
}
