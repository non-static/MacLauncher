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

    @State private var isHovered = false

    public init(
        app: AppItem,
        iconLoader: any AppIconLoading,
        isSelected: Bool = false,
        dropIndicator: AppTileDropIndicator = .none
    ) {
        self.app = app
        self.iconLoader = iconLoader
        self.isSelected = isSelected
        self.dropIndicator = dropIndicator
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: iconLoader.icon(for: app))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            Text(app.name)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: LauncherDesign.tileLabelWidth, height: 38, alignment: .top)
                .foregroundStyle(.primary)
        }
        .frame(width: LauncherDesign.tileWidth, height: LauncherDesign.tileHeight)
        .background(tileBackground)
        .overlay(tileBorder)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(dropIndicatorView)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .accessibilityLabel(app.name)
    }

    private var tileBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovered ? 0.18 : 0.12)
        }
        return isHovered ? Color.primary.opacity(0.08) : Color.clear
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
            .frame(width: 4, height: 92)
            .shadow(color: Color.accentColor.opacity(0.45), radius: 4)
            .padding(.horizontal, -6)
    }
}
