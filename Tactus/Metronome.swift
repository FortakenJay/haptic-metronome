import Foundation
import Observation
import os
import WatchKit

/// The metronome: tempo, play state, and the loop that taps the wrist on every beat.
///
/// The screen only reads this object and calls `toggle()`, `setTempo(_:)`, `step(by:)`, `cycleFeel()` and
/// `setMeter(_:)`.
/// The timing itself is `BeatClock` (pure, tested); this class just sleeps until each planned beat and
/// plays the haptic.
@MainActor
@Observable
final class Metronome {
    private(set) var bpm: Int
    private(set) var feel: Feel
    /// Time signature and grouping. `.off` means every beat is the same.
    private(set) var meter: Meter
    private(set) var isPlaying = false
    /// Position of the last beat that played within its bar (0 = beat 1). Drives the beat dots.
    private(set) var beatInBar = 0
    /// Goes up by one on every beat. The screen watches it to flash the ring.
    private(set) var beatCount = 0
    /// Why the metronome stopped on its own, shown until the next start.
    private(set) var notice: String?

    @ObservationIgnored private var clock = BeatClock(startingAt: 0, bpm: Tempo.defaultBPM)
    /// Beats played since start, or since the meter last changed, so the next beat after a change is beat 1.
    @ObservationIgnored private var beatIndex = 0
    @ObservationIgnored private var origin = ContinuousClock.now
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private let session = RuntimeSession()
    /// How many times one run may start a fresh session after watchOS ends one early. Reset by `start()`.
    @ObservationIgnored private var sessionRestartsLeft = 0
    private static let maxSessionRestarts = 3
    @ObservationIgnored private let log = Logger(subsystem: "com.fortakenjay.tactus", category: "metronome")
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let bpm = "tempo.bpm"
        static let feel = "tempo.feel"
        static let meter = "tempo.meter"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.integer(forKey: Key.bpm)   // 0 when never saved
        bpm = saved == 0 ? Tempo.defaultBPM : Tempo.clamped(Double(saved))
        feel = defaults.string(forKey: Key.feel).flatMap(Feel.init(rawValue:)) ?? .light
        meter = defaults.string(forKey: Key.meter).flatMap(Meter.with(id:)) ?? .off
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
        beatIndex = 0
        sessionRestartsLeft = Self.maxSessionRestarts
        log.info("start at \(self.bpm) BPM, meter \(self.meter.id, privacy: .public), feel \(self.feel.rawValue, privacy: .public)")
        session.begin()
        runLoop()
    }

    func stop(notice: String? = nil) {
        guard isPlaying else { return }
        log.info("stop: \(notice ?? "tapped", privacy: .public)")
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
            WKInterfaceDevice.current().play(feel.tap.haptic)   // a sample, so you know what you picked
        }
    }

    /// Changes the time signature. While playing, the very next beat becomes beat 1 of a new bar.
    func setMeter(_ newMeter: Meter) {
        guard newMeter != meter else { return }
        meter = newMeter
        defaults.set(newMeter.id, forKey: Key.meter)
        beatIndex = 0
        beatInBar = 0
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
        WKInterfaceDevice.current().play(meter.tap(atBeat: beatIndex, feel: feel).haptic)
        beatInBar = meter.position(ofBeat: beatIndex)
        beatIndex += 1
        beatCount &+= 1
        clock.beatPlayed(at: (ContinuousClock.now - origin).inSeconds)
    }

    // MARK: - Background session and app state

    /// The app is on screen and active again (wrist raised, or back in the app). If the beats are meant to be
    /// playing but the session is gone, start a fresh one: watchOS only allows that while the app is active.
    func appBecameActive() {
        guard isPlaying, !session.isActive else { return }
        log.notice("active while playing without a session: starting a new one")
        session.begin()
    }

    /// The app left the screen. Without a session nothing keeps the beat loop alive, so stop and say so.
    func appMovedToBackground() {
        guard isPlaying, !session.isActive else { return }
        stop(notice: "Stopped when you left")
    }

    private func sessionEnded(_ end: RuntimeSession.End) {
        switch end {
        case .expired:
            stop(notice: "Stopped after an hour")
        case .interrupted:
            // A session that ends early doesn't come back by itself, and without one the next wrist-down
            // silences the haptics (watchOS refuses them once the app isn't active). So while the app is still
            // active, start a fresh one right away. A few tries per run, so a session that keeps failing
            // can't loop; after that, stop honestly instead of showing "playing" with no taps.
            if WKApplication.shared().applicationState == .active && sessionRestartsLeft > 0 {
                sessionRestartsLeft -= 1
                log.notice("session ended early; starting a new one (\(self.sessionRestartsLeft) tries left)")
                session.begin()
            } else {
                stop(notice: "watchOS ended the session")
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
