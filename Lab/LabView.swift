import SwiftUI

/// Tactus Lab's one screen. Idle: crown sets the tempo, the toolbar picks the grid and calibrates, a tap starts a
/// take. Then a count-in, the live needle while you play, and the summary when you tap to stop.
struct LabView: View {
    let lab: LabSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                switch lab.phase {
                case .summary:
                    if let summary = lab.summary {
                        SummaryView(summary: summary, note: lab.message, onDone: lab.dismissSummary)
                    }
                case .calibrationQuiet(let left):
                    instruction("Don't play", detail: "Checking the watch can't hear its own taps", count: left)
                case .calibrationPlay(let left):
                    instruction("Play a key on every tap", detail: "Calibrating", count: left)
                default:
                    takeScreen
                }
            }
            .toolbar {
                if !lab.isRunning && lab.phase != .summary {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: lab.startCalibration) {
                            Image(systemName: "tuningfork")
                        }
                        .accessibilityLabel("Calibrate")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: lab.cycleSubdivision) {
                            Text(lab.subdivision.symbol).font(.body.weight(.semibold))
                        }
                        .accessibilityLabel("Grid")
                        .accessibilityValue(lab.subdivision.name)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lab.appMovedToBackground() }
        }
    }

    private var takeScreen: some View {
        Button(action: lab.toggle) {
            VStack(spacing: 6) {
                switch lab.phase {
                case .countIn(let left):
                    Text("\(left)")
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Count-in").font(.footnote).foregroundStyle(.secondary)
                case .listening:
                    TimingNeedle(deviation: lab.live)
                    Text("\(lab.notesHeard) notes · \(lab.subdivision.name.lowercased())")
                        .font(.caption2).foregroundStyle(.secondary)
                    Label("Tap to stop", systemImage: "stop.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                default:
                    Text(lab.bpm, format: .number)
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM · \(lab.subdivision.name.lowercased())")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(calibrationLine)
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let message = lab.message {
                        Text(message).font(.caption2).multilineTextAlignment(.center)
                    }
                    Label("Tap to start", systemImage: "play.fill")
                        .font(.footnote.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .digitalCrownRotation(
            Binding(get: { Double(lab.bpm) }, set: { lab.setTempo($0) }),
            from: Double(Tempo.range.lowerBound), through: Double(Tempo.range.upperBound), by: 1,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: !lab.isRunning
        )
        .accessibilityLabel(lab.isRunning ? "Stop take" : "Start take")
        .accessibilityValue("\(lab.bpm) beats per minute, \(lab.subdivision.name)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: lab.step(by: 1)
            case .decrement: lab.step(by: -1)
            @unknown default: break
            }
        }
    }

    private var calibrationLine: String {
        guard let calibration = lab.calibration else { return "Not calibrated: tap the tuning fork" }
        return "Calibrated \(calibration >= 0 ? "+" : "−")\(TakeSummary.ms(abs(calibration)))"
    }

    private func instruction(_ title: String, detail: String, count: Int) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.headline).multilineTextAlignment(.center)
            Text(detail).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(count > 0 ? "\(count)" : "…")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Button("Cancel") { lab.stop(reason: nil) }
        }
    }
}
