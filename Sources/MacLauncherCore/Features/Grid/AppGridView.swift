import SwiftUI

public struct AppGridView: View {
    private let apps: [AppItem]
    private let iconLoader: any AppIconLoading
    private let selectedAppID: AppItem.ID?
    private let onLaunch: (AppItem) -> Void
    private let onHide: (AppItem) -> Void
    private let onMoveInLayout: (AppItem, Int) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: LauncherDesign.tileMinWidth), spacing: 18)
    ]

    public init(
        apps: [AppItem],
        iconLoader: any AppIconLoading,
        selectedAppID: AppItem.ID? = nil,
        onLaunch: @escaping (AppItem) -> Void,
        onHide: @escaping (AppItem) -> Void = { _ in },
        onMoveInLayout: @escaping (AppItem, Int) -> Void = { _, _ in }
    ) {
        self.apps = apps
        self.iconLoader = iconLoader
        self.selectedAppID = selectedAppID
        self.onLaunch = onLaunch
        self.onHide = onHide
        self.onMoveInLayout = onMoveInLayout
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
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
            .padding(24)
        }
    }
}
