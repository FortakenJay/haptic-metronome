import Foundation
import Observation
import WatchKit

/// The metronome: tempo, play state, and the loop that taps the wrist on every beat.
///
/// The screen only reads this object and calls `toggle()`, `setTempo(_:)`, `step(by:)` and `cycleFeel()`.
/// The timing itself is `BeatClock` (pure, tested); this class just sleeps until each planned beat and
/// plays the haptic.
@MainActor
@Observable
final class Metronome {
    private(set) var bpm: Int
    private(set) var feel: Feel
    private(set) var isPlaying = false
    /// Goes up by one on every beat. The screen watches it to flash the ring.
    private(set) var beatCount = 0
    /// Why the metronome stopped on its own, shown until the next start.
    private(set) var notice: String?

    @ObservationIgnored private var clock = BeatClock(startingAt: 0, bpm: Tempo.defaultBPM)
    @ObservationIgnored private var origin = ContinuousClock.now
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private let session = RuntimeSession()
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let bpm = "tempo.bpm"
        static let feel = "tempo.feel"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.integer(forKey: Key.bpm)   // 0 when never saved
        bpm = saved == 0 ? Tempo.defaultBPM : Tempo.clamped(Double(saved))
        feel = defaults.string(forKey: Key.feel).flatMap(Feel.init(rawValue:)) ?? .light
        session.onEnd = { [weak self] end in self?.sessionEnded(end) }
    }

    // MARK: - Controls

    func toggle() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isPlaying else { return }
        notice = nil
        isPlaying = true
        origin = .now
        clock = BeatClock(startingAt: 0, bpm: bpm)   // first beat right away
        session.begin()
        runLoop()
    }

    func stop(notice: String? = nil) {
        guard isPlaying else { return }
        isPlaying = false
        self.notice = notice
        loop?.cancel()
        loop = nil
        session.end()
    }

    /// Sets the tempo from the crown. While playing, the change lands on the next beat with no jump.
    func setTempo(_ value: Double) {
        let newBPM = Tempo.clamped(value)
        guard newBPM != bpm else { return }
        bpm = newBPM
        defaults.set(newBPM, forKey: Key.bpm)
        guard isPlaying else { return }
        clock.setTempo(newBPM)
        runLoop()   // the loop was asleep until the old next beat; wake it for the new one
    }

    /// One BPM up or down, for VoiceOver's swipe-up and swipe-down.
    func step(by delta: Int) {
        setTempo(Double(bpm + delta))
    }

    func cycleFeel() {
        feel = feel.next
        defaults.set(feel.rawValue, forKey: Key.feel)
        if !isPlaying {
            WKInterfaceDevice.current().play(feel.haptic)   // a sample, so you know what you picked
        }
    }

    // MARK: - Beat loop

    private func runLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let due = self.origin + .seconds(self.clock.nextBeat)
                do {
                    try await Task.sleep(until: due, tolerance: .zero, clock: .continuous)
                } catch {
                    return   // cancelled: stopped, or the tempo changed and a new loop took over
                }
                self.playBeat()
            }
        }
    }

    private func playBeat() {
        WKInterfaceDevice.current().play(feel.haptic)
        beatCount &+= 1
        clock.beatPlayed(at: (ContinuousClock.now - origin).inSeconds)
    }

    // MARK: - Background session

    private func sessionEnded(_ end: RuntimeSession.End) {
        switch end {
        case .expired:
            stop(notice: "Stopped after an hour")
        case .interrupted:
            // With the app still on screen the beats keep going; only the wrist-down part is lost.
            // If the app has left the screen, nothing can keep the loop alive, so say so and stop.
            if WKApplication.shared().applicationState != .active {
                stop(notice: "Stopped when you left")
            }
        }
    }
}

private extension Duration {
    var inSeconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) * 1e-18
    }
}
