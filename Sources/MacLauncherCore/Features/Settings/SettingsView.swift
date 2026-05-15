import SwiftUI

public struct SettingsView: View {
    @Binding private var backgroundTransparencyPercent: Double
    @Binding private var displayLoadTimeInMilliseconds: Bool

    public init(
        backgroundTransparencyPercent: Binding<Double>,
        displayLoadTimeInMilliseconds: Binding<Bool>
    ) {
        self._backgroundTransparencyPercent = backgroundTransparencyPercent
        self._displayLoadTimeInMilliseconds = displayLoadTimeInMilliseconds
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
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
