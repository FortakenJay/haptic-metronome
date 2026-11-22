import SwiftUI

/// A tuner-style needle for timing: left is early, right is late, the middle is on the beat. The scale runs to
/// ±60 ms. The words under it carry the same information, so the needle is never the only cue.
struct TimingNeedle: View {
    /// Seconds; negative is early. Nil before the first note.
    let deviation: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let range = 0.060

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                    // ±10 ms band: "on the beat"
                    Capsule()
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: width * TakeSummary.onBeat / Self.range, height: 6)
                        .offset(x: width / 2 - width * TakeSummary.onBeat / Self.range / 2)
                    Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 1.5, height: 14)
                        .offset(x: width / 2 - 0.75)
                    if let deviation {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                            .offset(x: position(deviation, width: width) - 7)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: deviation)
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            HStack {
                Text("early").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("late").font(.caption2).foregroundStyle(.secondary)
            }
            Text(deviation.map(TakeSummary.describe) ?? "Listening…")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timing")
        .accessibilityValue(deviation.map(TakeSummary.describe) ?? "No notes yet")
    }

    private func position(_ deviation: Double, width: CGFloat) -> CGFloat {
        let clamped = min(Self.range, max(-Self.range, deviation))
        return width / 2 + CGFloat(clamped / Self.range) * width / 2
    }
}

#Preview {
    VStack(spacing: 20) {
        TimingNeedle(deviation: -0.024)
        TimingNeedle(deviation: 0.004)
        TimingNeedle(deviation: nil)
    }
    .padding()
}
