import SwiftUI

public struct SettingsView: View {
    @Binding private var backgroundTransparencyPercent: Double
    @Binding private var displayLoadTimeInMilliseconds: Bool
    @Binding private var showsSystemApps: Bool
    @Binding private var showsHiddenApps: Bool
    @Binding private var tileSize: LauncherTileSize
    @Binding private var columnMode: LauncherColumnMode
    @Binding private var fixedColumnCount: Int
    @Binding private var startsAtLogin: Bool
    @Binding private var hotkey: LauncherHotkeyOption

    private let onResetLayout: () -> Void

    public init(
        backgroundTransparencyPercent: Binding<Double>,
        displayLoadTimeInMilliseconds: Binding<Bool>,
        showsSystemApps: Binding<Bool>,
        showsHiddenApps: Binding<Bool>,
        tileSize: Binding<LauncherTileSize>,
        columnMode: Binding<LauncherColumnMode>,
        fixedColumnCount: Binding<Int>,
        startsAtLogin: Binding<Bool>,
        hotkey: Binding<LauncherHotkeyOption>,
        onResetLayout: @escaping () -> Void
    ) {
        self._backgroundTransparencyPercent = backgroundTransparencyPercent
        self._displayLoadTimeInMilliseconds = displayLoadTimeInMilliseconds
        self._showsSystemApps = showsSystemApps
        self._showsHiddenApps = showsHiddenApps
        self._tileSize = tileSize
        self._columnMode = columnMode
        self._fixedColumnCount = fixedColumnCount
        self._startsAtLogin = startsAtLogin
        self._hotkey = hotkey
        self.onResetLayout = onResetLayout
    }

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Background Transparency", systemImage: "circle.lefthalf.filled")
                        Spacer()
                        Text("\(Int(backgroundTransparencyPercent.rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $backgroundTransparencyPercent,
                        in: 0...100,
                        step: 1
                    )

                    HStack {
                        Text("Opaque")
                        Spacer()
                        Text("Clear")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(isOn: $displayLoadTimeInMilliseconds) {
                    Label("Display Load Time", systemImage: "timer")
                }
            }

            Section {
                Toggle(isOn: $showsSystemApps) {
                    Label("Show System Apps", systemImage: "macwindow.badge.plus")
                }

                Toggle(isOn: $showsHiddenApps) {
                    Label("Show Hidden Apps", systemImage: "eye")
                }

                Button(role: .destructive) {
                    onResetLayout()
                } label: {
                    Label("Reset Layout", systemImage: "arrow.counterclockwise")
                }
            }

            Section {
                Picker(selection: $tileSize) {
                    ForEach(LauncherTileSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                } label: {
                    Label("Tile Size", systemImage: "square.resize")
                }

                Picker(selection: $columnMode) {
                    ForEach(LauncherColumnMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                } label: {
                    Label("Columns", systemImage: "rectangle.grid.3x2")
                }

                if columnMode == .fixed {
                    Stepper(value: $fixedColumnCount, in: 2...8) {
                        Label("\(fixedColumnCount) Columns", systemImage: "number")
                    }
                }
            }

            Section {
                Toggle(isOn: $startsAtLogin) {
                    Label("Open at Login", systemImage: "power")
                }

                Picker(selection: $hotkey) {
                    ForEach(LauncherHotkeyOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Label("Hotkey", systemImage: "keyboard")
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
