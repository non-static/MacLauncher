import SwiftUI

public struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel
    private let iconLoader: any AppIconLoading

    public init(viewModel: HomeViewModel, iconLoader: any AppIconLoading) {
        self.viewModel = viewModel
        self.iconLoader = iconLoader
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
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
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
