import SwiftUI

public struct AppTileView: View {
    private let app: AppItem
    private let iconLoader: any AppIconLoading
    private let isSelected: Bool
    private let isDropTarget: Bool

    @State private var isHovered = false

    public init(
        app: AppItem,
        iconLoader: any AppIconLoading,
        isSelected: Bool = false,
        isDropTarget: Bool = false
    ) {
        self.app = app
        self.iconLoader = iconLoader
        self.isSelected = isSelected
        self.isDropTarget = isDropTarget
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
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .accessibilityLabel(app.name)
    }

    private var tileBackground: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.2)
        }
        if isSelected {
            return Color.accentColor.opacity(isHovered ? 0.18 : 0.12)
        }
        return isHovered ? Color.primary.opacity(0.08) : Color.clear
    }

    @ViewBuilder
    private var tileBorder: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        if isDropTarget {
            shape.strokeBorder(
                Color.accentColor.opacity(0.9),
                style: StrokeStyle(lineWidth: 2, dash: [5, 3])
            )
        } else {
            shape.strokeBorder(
                isSelected ? Color.accentColor.opacity(0.78) : Color.clear,
                lineWidth: 2
            )
        }
    }
}
