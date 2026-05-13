import SwiftUI

public struct AppTileView: View {
    private let app: AppItem
    private let iconLoader: any AppIconLoading
    private let isSelected: Bool

    @State private var isHovered = false

    public init(
        app: AppItem,
        iconLoader: any AppIconLoading,
        isSelected: Bool = false
    ) {
        self.app = app
        self.iconLoader = iconLoader
        self.isSelected = isSelected
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
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.78) : Color.clear,
                    lineWidth: 2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
}
