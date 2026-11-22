import SwiftUI

/// The list of time signatures. Picking one closes the sheet; the next beat becomes beat 1 of a new bar.
struct MeterPicker: View {
    let selection: Meter
    let onPick: (Meter) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Meter.all) { meter in
                        Button { onPick(meter) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(meter.label)
                                        .font(.body.weight(.semibold))
                                        .monospacedDigit()
                                    if let grouping = meter.groupingLabel {
                                        Text(grouping)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else if meter.isOff {
                                        Text("Every beat the same")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if meter == selection {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .accessibilityLabel(meter.isOff ? "Off, every beat the same" : meter.spokenLabel)
                        .accessibilityAddTraits(meter == selection ? .isSelected : [])
                    }
                } footer: {
                    Text("The first beat of each group taps Strong, the rest Light. In /8 meters the tempo counts eighth notes.")
                }
            }
            .navigationTitle("Time signature")
        }
    }
}

#Preview {
    MeterPicker(selection: Meter(7, 8, groups: [2, 2, 3])) { _ in }
}
