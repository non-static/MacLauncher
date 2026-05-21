import SwiftUI

public enum AppTileDropIndicator: Equatable {
    case none
    case before
    case after
}

public struct AppTileView: View {
    private let app: AppItem
    private let iconLoader: any AppIconLoading
    private let isSelected: Bool
    private let dropIndicator: AppTileDropIndicator
    private let tileSize: LauncherTileSize

    @State private var isHovered = false
    @State private var icon: NSImage?

    public init(
        app: AppItem,
        iconLoader: any AppIconLoading,
        isSelected: Bool = false,
        dropIndicator: AppTileDropIndicator = .none,
        tileSize: LauncherTileSize = .medium
    ) {
        self.app = app
        self.iconLoader = iconLoader
        self.isSelected = isSelected
        self.dropIndicator = dropIndicator
        self.tileSize = tileSize
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: icon ?? Self.placeholderIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: metrics.iconLength, height: metrics.iconLength)

            Text(app.name)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: metrics.labelWidth, height: metrics.labelHeight, alignment: .top)
                .foregroundStyle(.primary)
        }
        .frame(width: metrics.width, height: metrics.height)
        .background(tileBackground)
        .overlay(tileBorder)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(dropIndicatorView)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .task(id: app.iconCacheKey) {
            await loadIcon()
        }
        .accessibilityLabel(app.name)
    }

    private var tileBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovered ? 0.18 : 0.12)
        }
        return isHovered ? Color.primary.opacity(0.08) : Color.clear
    }

    private var metrics: LauncherTileMetrics {
        tileSize.metrics
    }

    @ViewBuilder
    private var tileBorder: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        shape.strokeBorder(
            isSelected ? Color.accentColor.opacity(0.78) : Color.clear,
            lineWidth: 2
        )
    }

    @ViewBuilder
    private var dropIndicatorView: some View {
        switch dropIndicator {
        case .none:
            EmptyView()
        case .before:
            HStack {
                insertionMarker
                Spacer()
            }
        case .after:
            HStack {
                Spacer()
                insertionMarker
            }
        }
    }

    private var insertionMarker: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 4, height: max(72, metrics.height - 28))
            .shadow(color: Color.accentColor.opacity(0.45), radius: 4)
            .padding(.horizontal, -6)
    }

    private func loadIcon() async {
        let app = app
        let iconLoader = iconLoader
        let loadedIcon = await Task.detached(priority: .utility) {
            iconLoader.icon(for: app)
        }.value

        guard Task.isCancelled == false else {
            return
        }

        icon = loadedIcon
    }

    private static var placeholderIcon: NSImage {
        NSImage(
            systemSymbolName: "app.dashed",
            accessibilityDescription: nil
        ) ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}
