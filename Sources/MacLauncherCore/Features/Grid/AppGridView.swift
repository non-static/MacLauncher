import SwiftUI

public struct AppGridView: View {
    private let apps: [AppItem]
    private let iconLoader: any AppIconLoading
    private let selectedAppID: AppItem.ID?
    private let onLaunch: (AppItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: LauncherDesign.tileMinWidth), spacing: 18)
    ]

    public init(
        apps: [AppItem],
        iconLoader: any AppIconLoading,
        selectedAppID: AppItem.ID? = nil,
        onLaunch: @escaping (AppItem) -> Void
    ) {
        self.apps = apps
        self.iconLoader = iconLoader
        self.selectedAppID = selectedAppID
        self.onLaunch = onLaunch
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
                }
            }
            .padding(24)
        }
    }
}
