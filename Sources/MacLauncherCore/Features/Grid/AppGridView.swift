import SwiftUI
import UniformTypeIdentifiers

public struct AppGridView: View {
    private let apps: [AppItem]
    private let groups: [AppGroup]
    private let iconLoader: any AppIconLoading
    private let selectedAppID: AppItem.ID?
    private let onLaunch: (AppItem) -> Void
    private let onHide: (AppItem) -> Void
    private let onCreateGroup: (AppItem) -> Void
    private let onMoveToGroup: (AppItem, AppGroup.ID) -> Void
    private let onMoveInLayout: (AppItem, Int) -> Void
    private let onReorder: (AppItem.ID, Int) -> Bool
    private let onColumnCountChange: (Int) -> Void

    @State private var draggedAppID: AppItem.ID?
    @State private var dropTarget: AppGridDropTarget?
    @State private var scrollRequest: AppGridScrollRequest?

    private let columns = [
        GridItem(.adaptive(minimum: LauncherDesign.tileMinWidth), spacing: Self.gridSpacing)
    ]

    private static let gridSpacing: CGFloat = 18
    private static let gridPadding: CGFloat = 24
    private static let edgeScrollZoneHeight: CGFloat = 52
    private static let dropSlotWidth = (LauncherDesign.tileWidth / 2) + gridSpacing

    public init(
        apps: [AppItem],
        groups: [AppGroup] = [],
        iconLoader: any AppIconLoading,
        selectedAppID: AppItem.ID? = nil,
        onLaunch: @escaping (AppItem) -> Void,
        onHide: @escaping (AppItem) -> Void = { _ in },
        onCreateGroup: @escaping (AppItem) -> Void = { _ in },
        onMoveToGroup: @escaping (AppItem, AppGroup.ID) -> Void = { _, _ in },
        onMoveInLayout: @escaping (AppItem, Int) -> Void = { _, _ in },
        onReorder: @escaping (AppItem.ID, Int) -> Bool = { _, _ in false },
        onColumnCountChange: @escaping (Int) -> Void = { _ in }
    ) {
        self.apps = apps
        self.groups = groups
        self.iconLoader = iconLoader
        self.selectedAppID = selectedAppID
        self.onLaunch = onLaunch
        self.onHide = onHide
        self.onCreateGroup = onCreateGroup
        self.onMoveToGroup = onMoveToGroup
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
                            ZStack {
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

                                    Divider()

                                    Button("New Group from App") {
                                        onCreateGroup(app)
                                    }

                                    if groups.isEmpty == false {
                                        Menu("Move to Group") {
                                            ForEach(groups) { group in
                                                Button(group.name) {
                                                    onMoveToGroup(app, group.id)
                                                }
                                            }
                                        }
                                    }
                                }

                                dropSlot(
                                    app: app,
                                    insertionIndex: index,
                                    indicator: .before
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)

                                dropSlot(
                                    app: app,
                                    insertionIndex: index + 1,
                                    indicator: .after
                                )
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .frame(width: LauncherDesign.tileWidth, height: LauncherDesign.tileHeight)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .padding(Self.gridPadding)
                    .animation(.easeInOut(duration: 0.16), value: apps.map(\.id))
                }
                .overlay(alignment: .top) {
                    edgeScrollZone(
                        edge: .top,
                        rowStride: Self.estimatedColumnCount(for: geometry.size.width)
                    )
                }
                .overlay(alignment: .bottom) {
                    edgeScrollZone(
                        edge: .bottom,
                        rowStride: Self.estimatedColumnCount(for: geometry.size.width)
                    )
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
                .onChange(of: scrollRequest) { _, request in
                    guard let request else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.16)) {
                        proxy.scrollTo(request.appID, anchor: request.anchor)
                    }
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

    private func dropSlot(
        app: AppItem,
        insertionIndex: Int,
        indicator: AppTileDropIndicator
    ) -> some View {
        Color.clear
            .frame(width: Self.dropSlotWidth, height: LauncherDesign.tileHeight)
            .offset(x: indicator == .before ? -(Self.gridSpacing / 2) : Self.gridSpacing / 2)
            .contentShape(Rectangle())
            .allowsHitTesting(draggedAppID != nil)
            .onDrop(
                of: [UTType.plainText],
                delegate: AppGridDropDelegate(
                    target: AppGridDropTarget(
                        appID: app.id,
                        insertionIndex: insertionIndex,
                        indicator: indicator
                    ),
                    appIDs: apps.map(\.id),
                    draggedAppID: $draggedAppID,
                    dropTarget: $dropTarget,
                    onReorder: onReorder
                )
            )
    }

    private func edgeScrollZone(
        edge: AppGridEdge,
        rowStride: Int
    ) -> some View {
        Color.clear
            .frame(height: Self.edgeScrollZoneHeight)
            .contentShape(Rectangle())
            .allowsHitTesting(draggedAppID != nil)
            .onDrop(
                of: [UTType.plainText],
                delegate: AppGridEdgeDropDelegate(
                    edge: edge,
                    appIDs: apps.map(\.id),
                    rowStride: rowStride,
                    draggedAppID: $draggedAppID,
                    dropTarget: $dropTarget,
                    scrollRequest: $scrollRequest,
                    onReorder: onReorder
                )
            )
    }
}

private enum AppGridEdge {
    case top
    case bottom
}

private struct AppGridScrollRequest: Equatable {
    let appID: AppItem.ID
    let anchor: UnitPoint
    let nonce = UUID()

    static func == (lhs: AppGridScrollRequest, rhs: AppGridScrollRequest) -> Bool {
        lhs.nonce == rhs.nonce
    }
}

private struct AppGridDropTarget: Equatable {
    let appID: AppItem.ID
    let insertionIndex: Int
    let indicator: AppTileDropIndicator
}

private struct AppGridDropDelegate: DropDelegate {
    let target: AppGridDropTarget
    let appIDs: [AppItem.ID]

    @Binding var draggedAppID: AppItem.ID?
    @Binding var dropTarget: AppGridDropTarget?

    let onReorder: (AppItem.ID, Int) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedAppID,
              let currentIndex = appIDs.firstIndex(of: draggedAppID),
              appIDs.contains(target.appID),
              target.insertionIndex >= 0,
              target.insertionIndex <= appIDs.count
        else {
            return false
        }
        return target.insertionIndex != currentIndex
            && target.insertionIndex != currentIndex + 1
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else {
            return DropProposal(operation: .cancel)
        }

        dropTarget = target
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.1)) {
            dropTarget = target
        }
    }

    func dropExited(info: DropInfo) {
        guard dropTarget?.appID == target.appID else {
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

        guard let draggedAppID, validateDrop(info: info) else {
            return false
        }

        return onReorder(draggedAppID, target.insertionIndex)
    }
}

private struct AppGridEdgeDropDelegate: DropDelegate {
    let edge: AppGridEdge
    let appIDs: [AppItem.ID]
    let rowStride: Int

    @Binding var draggedAppID: AppItem.ID?
    @Binding var dropTarget: AppGridDropTarget?
    @Binding var scrollRequest: AppGridScrollRequest?

    let onReorder: (AppItem.ID, Int) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        target() != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let target = target() else {
            return DropProposal(operation: .cancel)
        }

        dropTarget = target
        scrollRequest = scrollRequest(for: target)
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let target = target() else {
            return
        }

        dropTarget = target
        scrollRequest = scrollRequest(for: target)
    }

    func dropExited(info: DropInfo) {
        dropTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedAppID = nil
            dropTarget = nil
        }

        guard let draggedAppID, let target = target() else {
            return false
        }

        return onReorder(draggedAppID, target.insertionIndex)
    }

    private func target() -> AppGridDropTarget? {
        guard let draggedAppID,
              let currentIndex = appIDs.firstIndex(of: draggedAppID),
              appIDs.isEmpty == false
        else {
            return nil
        }

        let stride = max(1, rowStride)
        let baseIndex = dropTarget?.insertionIndex ?? currentIndex
        let insertionIndex: Int
        switch edge {
        case .top:
            insertionIndex = max(0, baseIndex - stride)
        case .bottom:
            insertionIndex = min(appIDs.count, baseIndex + stride)
        }

        guard insertionIndex != currentIndex,
              insertionIndex != currentIndex + 1
        else {
            return nil
        }

        let indicator: AppTileDropIndicator
        let targetAppID: AppItem.ID
        if insertionIndex == appIDs.count {
            targetAppID = appIDs[appIDs.count - 1]
            indicator = .after
        } else {
            targetAppID = appIDs[insertionIndex]
            indicator = .before
        }

        return AppGridDropTarget(
            appID: targetAppID,
            insertionIndex: insertionIndex,
            indicator: indicator
        )
    }

    private func scrollRequest(for target: AppGridDropTarget) -> AppGridScrollRequest {
        AppGridScrollRequest(
            appID: target.appID,
            anchor: edge == .top ? .top : .bottom
        )
    }
}
