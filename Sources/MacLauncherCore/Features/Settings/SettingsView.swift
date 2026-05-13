import SwiftUI

public struct SettingsView: View {
    @Binding private var backgroundTransparencyPercent: Double

    public init(backgroundTransparencyPercent: Binding<Double>) {
        self._backgroundTransparencyPercent = backgroundTransparencyPercent
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
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
