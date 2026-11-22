import SwiftUI

/// The one screen. Turn the crown to change tempo, tap anywhere to start or stop. The time signature button at
/// the top left picks a meter; the beat dots under the dial show where you are in the bar.
///
/// Interaction rules it follows:
/// - Turning the crown is high-frequency, so the number changes instantly, with no animation.
/// - Crown detent clicks are switched off while playing, so the only taps on the wrist are beats.
/// - Play state is never carried by motion or colour alone: the icon and the words change too.
/// - With Reduce Motion on, the beat flash and the press only fade; nothing scales.
struct MetronomeView: View {
    /// Owned by `TactusApp`, not by this view, so rebuilding the view can never release a running session.
    let metronome: Metronome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase
    @State private var choosingMeter = false

    var body: some View {
        NavigationStack {
            Button(action: metronome.toggle) {
                VStack(spacing: 6) {
                    dial
                    if !metronome.meter.isOff && !isLuminanceReduced {
                        BeatDots(meter: metronome.meter, current: metronome.beatInBar, isPlaying: metronome.isPlaying)
                    }
                    status
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())   // the whole screen is the button, not just the text
            }
            .buttonStyle(PressStyle())
            .focusable()
            .focusEffectDisabled()
            .digitalCrownRotation(
                tempoBinding,
                from: Double(Tempo.range.lowerBound),
                through: Double(Tempo.range.upperBound),
                by: 1,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: !metronome.isPlaying
            )
            .accessibilityLabel(metronome.isPlaying ? "Stop metronome" : "Start metronome")
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: metronome.step(by: 1)
                case .decrement: metronome.step(by: -1)
                @unknown default: break
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { choosingMeter = true } label: {
                        if metronome.meter.isOff {
                            Image(systemName: "music.note")
                        } else {
                            Text(metronome.meter.label)
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                    .accessibilityLabel("Time signature")
                    .accessibilityValue(metronome.meter.spokenLabel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Feel only matters with no meter: with one, group starts are Strong and the rest Light.
                    Button(action: metronome.cycleFeel) {
                        Image(systemName: metronome.feel == .strong ? "hand.tap.fill" : "hand.tap")
                    }
                    .disabled(!metronome.meter.isOff)
                    .accessibilityLabel("Beat feel")
                    .accessibilityValue(metronome.meter.isOff ? metronome.feel.name : "Set by the time signature")
                }
            }
            .sheet(isPresented: $choosingMeter) {
                MeterPicker(selection: metronome.meter) { meter in
                    metronome.setMeter(meter)
                    choosingMeter = false
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: metronome.appBecameActive()
            case .background: metronome.appMovedToBackground()
            default: break   // .inactive: wrist down or Always On; the session keeps the app running
            }
        }
        #if DEBUG
        .task { await autostartForScreenshots() }
        #endif
    }

    #if DEBUG
    /// Screenshot hook, Debug builds only. Launching with `-tactus.autostart YES` starts playing a second after
    /// launch. `scripts/screenshots.sh` uses it because a simulator can't be tapped from the command line.
    private func autostartForScreenshots() async {
        guard UserDefaults.standard.bool(forKey: "tactus.autostart") else { return }
        try? await Task.sleep(for: .seconds(1))
        metronome.start()
    }
    #endif

    // MARK: - Pieces

    /// The ring with the tempo inside it. The ring lights up on every beat.
    private var dial: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: 6)

            if metronome.isPlaying && !isLuminanceReduced {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 6)
                    .keyframeAnimator(initialValue: BeatPulse(), trigger: metronome.beatCount) { ring, pulse in
                        ring
                            .scaleEffect(pulse.scale)
                            .opacity(pulse.glow)
                    } keyframes: { _ in
                        // 0.21 s in total, shorter than one beat at the 240 BPM ceiling (0.25 s).
                        KeyframeTrack(\.glow) {
                            LinearKeyframe(1, duration: 0.01)
                            CubicKeyframe(0, duration: 0.2)
                        }
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(reduceMotion ? 1 : 1.06, duration: 0.05)
                            CubicKeyframe(1, duration: 0.16)
                        }
                    }
            }

            VStack(spacing: 0) {
                Text(metronome.bpm, format: .number)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()   // digits keep one width, so turning the crown never jiggles the number
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(metronome.meter.countsEighths ? "BPM ♪" : "BPM")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(14)
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isLuminanceReduced ? 0.6 : 1)
    }

    /// What tapping will do, plus why it stopped if it stopped on its own.
    private var status: some View {
        VStack(spacing: 0) {
            if let notice = metronome.notice, !metronome.isPlaying {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Label {
                Text(metronome.isPlaying ? "Tap to stop" : "Tap to start")
            } icon: {
                Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                    .contentTransition(
                        reduceMotion ? ContentTransition.opacity : ContentTransition.symbolEffect(.replace)
                    )
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(metronome.isPlaying ? Color.accentColor : .primary)
        }
    }

    // MARK: - Helpers

    private var trackColor: Color {
        metronome.isPlaying ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.35)
    }

    /// The crown writes through `setTempo`, which rounds, clamps, saves and retimes the beat.
    private var tempoBinding: Binding<Double> {
        Binding(
            get: { Double(metronome.bpm) },
            set: { metronome.setTempo($0) }
        )
    }

    /// Under the number: the Italian marking for quarter-note meters, the grouping for odd ones ("Andante · 3+2"),
    /// and only the grouping for /8 meters, where an Italian name for an eighth-note count would mislead.
    private var subtitle: String {
        let meter = metronome.meter
        var parts: [String] = []
        if !meter.countsEighths { parts.append(Tempo.marking(for: metronome.bpm)) }
        if let grouping = meter.groupingLabel { parts.append(grouping) }
        return parts.joined(separator: " · ")
    }

    private var accessibilityValue: String {
        let meter = metronome.meter
        let unit = meter.countsEighths ? "eighth notes per minute" : "beats per minute"
        var parts = ["\(metronome.bpm) \(unit)"]
        if !meter.countsEighths { parts.append(Tempo.marking(for: metronome.bpm)) }
        if !meter.isOff { parts.append(meter.spokenLabel) }
        if let notice = metronome.notice, !metronome.isPlaying {
            parts.append(notice)
        }
        return parts.joined(separator: ", ")
    }
}

/// Values the beat flash animates between.
private struct BeatPulse {
    var scale = 1.0
    var glow = 0.0
}

/// Pressed state: scale to 0.96 over 150 ms, ease-out. Under Reduce Motion, a fade instead of a scale.
private struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    MetronomeView(metronome: Metronome())
}
