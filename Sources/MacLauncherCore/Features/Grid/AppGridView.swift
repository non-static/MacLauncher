import SwiftUI

public struct AppGridView: View {
    private let apps: [AppItem]
    private let iconLoader: any AppIconLoading
    private let selectedAppID: AppItem.ID?
    private let onLaunch: (AppItem) -> Void
    private let onHide: (AppItem) -> Void
    private let onMoveInLayout: (AppItem, Int) -> Void
    private let onColumnCountChange: (Int) -> Void

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
        onColumnCountChange: @escaping (Int) -> Void = { _ in }
    ) {
        self.apps = apps
        self.iconLoader = iconLoader
        self.selectedAppID = selectedAppID
        self.onLaunch = onLaunch
        self.onHide = onHide
        self.onMoveInLayout = onMoveInLayout
        self.onColumnCountChange = onColumnCountChange
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
                        ForEach(apps) { app in
                            Button {
                                onLaunch(app)
                            } label: {
                                AppTileView(
                                    app: app,
                                    iconLoader: iconLoader,
                                    isSelected: app.id == selectedAppID
                                )
                            }
                            .buttonStyle(.plain)
                            .id(app.id)
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
                    scrollToSelection(with: proxy)
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
}
