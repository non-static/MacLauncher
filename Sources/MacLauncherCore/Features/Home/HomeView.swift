import SwiftUI

public struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel
    private let iconLoader: any AppIconLoading
    private let backgroundTransparencyPercent: Double
    private let onOpenSettings: () -> Void

    public init(
        viewModel: HomeViewModel,
        iconLoader: any AppIconLoading,
        backgroundTransparencyPercent: Double,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.iconLoader = iconLoader
        self.backgroundTransparencyPercent = backgroundTransparencyPercent
        self.onOpenSettings = onOpenSettings
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
        }
        .onAppear {
            if viewModel.apps.isEmpty {
                viewModel.refresh()
            }
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
                Text("\(viewModel.apps.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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

    private var footer: some View {
        HStack {
            Spacer()
            Text("Command-, opens Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.apps.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.apps.isEmpty {
            ContentUnavailableView(
                "No Applications Found",
                systemImage: "app.dashed"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AppGridView(
                apps: viewModel.apps,
                iconLoader: iconLoader,
                onLaunch: viewModel.launch
            )
        }
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
