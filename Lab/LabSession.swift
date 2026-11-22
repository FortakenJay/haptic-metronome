import AVFAudio
import Foundation
import Observation
import os
import WatchKit

/// Grid the notes are checked against.
enum Subdivision: Int, CaseIterable {
    case quarter = 1, eighth = 2, triplet = 3, sixteenth = 4

    var symbol: String {
        switch self {
        case .quarter: "♩"
        case .eighth: "♪"
        case .triplet: "3"
        case .sixteenth: "♬"
        }
    }

    var name: String {
        switch self {
        case .quarter: "Quarter notes"
        case .eighth: "Eighth notes"
        case .triplet: "Triplets"
        case .sixteenth: "Sixteenth notes"
        }
    }

    var next: Subdivision {
        Self(rawValue: rawValue % 4 + 1)!
    }
}

/// Tactus Lab: plays a click on the wrist, listens to the piano and measures how early or late each note is.
///
/// A take is a 4-beat count-in (Strong taps) then the click (Light taps) while the microphone listens. Stopping
/// shows the summary. Calibration plays 4 taps to stay quiet through, then 8 to play along with; it measures
/// whether the watch hears its own taps and the constant offset between the tap and your note.
@MainActor
@Observable
final class LabSession {
    enum Phase: Equatable {
        case idle
        case countIn(beatsLeft: Int)
        case listening
        case calibrationQuiet(beatsLeft: Int)
        case calibrationPlay(beatsLeft: Int)
        case summary
    }

    private(set) var bpm: Int
    private(set) var subdivision: Subdivision
    private(set) var phase: Phase = .idle
    /// Median deviation of the last few notes, for the needle. Negative is early.
    private(set) var live: Double?
    private(set) var notesHeard = 0
    private(set) var summary: TakeSummary?
    /// Your calibration, in seconds. Nil until calibrated.
    private(set) var calibration: Double?
    /// Something to tell you: a calibration result or why something failed.
    private(set) var message: String?
    private(set) var beatCount = 0

    var isRunning: Bool {
        switch phase {
        case .idle, .summary: false
        default: true
        }
    }

    static let countIn = 4
    static let calibrationBPM = 80
    static let calibrationQuietBeats = 4
    static let calibrationPlayBeats = 8

    @ObservationIgnored private var clock = BeatClock(startingAt: 0, bpm: Tempo.defaultBPM)
    @ObservationIgnored private var originHost = 0.0
    @ObservationIgnored private var originInstant = SuspendingClock.now
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var beatIndex = 0
    @ObservationIgnored private var beatTimes: [Double] = []
    @ObservationIgnored private var onsets: [Double] = []
    @ObservationIgnored private var analyzer: TimingAnalyzer?
    @ObservationIgnored private var calibrating = false
    @ObservationIgnored private let audio = AudioInput()
    @ObservationIgnored private let session = RuntimeSession()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "com.fortakenjay.tactus.lab", category: "lab")

    private enum Key {
        static let bpm = "lab.bpm", subdivision = "lab.subdivision", calibration = "lab.calibration"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.integer(forKey: Key.bpm)
        bpm = saved == 0 ? Tempo.defaultBPM : Tempo.clamped(Double(saved))
        subdivision = Subdivision(rawValue: defaults.integer(forKey: Key.subdivision)) ?? .sixteenth
        calibration = defaults.object(forKey: Key.calibration) as? Double
        session.onEnd = { [weak self] end in
            self?.stop(reason: end == .expired ? "Stopped after an hour" : "watchOS ended the session")
        }
    }

    // MARK: - Settings

    func setTempo(_ value: Double) {
        guard !isRunning else { return }
        bpm = Tempo.clamped(value)
        defaults.set(bpm, forKey: Key.bpm)
    }

    func step(by delta: Int) { setTempo(Double(bpm + delta)) }

    func cycleSubdivision() {
        guard !isRunning else { return }
        subdivision = subdivision.next
        defaults.set(subdivision.rawValue, forKey: Key.subdivision)
    }

    func dismissSummary() {
        phase = .idle
    }

    // MARK: - Take

    func toggle() {
        isRunning ? stop(reason: nil) : startTake()
    }

    func startTake() {
        Task { await begin(calibration: false) }
    }

    func startCalibration() {
        Task { await begin(calibration: true) }
    }

    private func begin(calibration isCalibration: Bool) async {
        guard !isRunning else { return }
        message = nil
        guard await microphoneAllowed() else {
            message = "Microphone access is off. Turn it on in Settings → Privacy & Security → Microphone."
            return
        }
        guard !isRunning else { return }   // tapped twice while the permission prompt was up
        onsets = []
        beatTimes = []
        live = nil
        notesHeard = 0
        calibrating = isCalibration
        do {
            try audio.start { [weak self] found in
                Task { @MainActor in self?.receive(found) }
            }
        } catch {
            message = "Couldn't start the microphone: \(error.localizedDescription)"
            return
        }
        session.begin()

        let tempo = isCalibration ? Self.calibrationBPM : bpm
        let interval = Tempo.interval(for: tempo)
        originHost = hostNow()
        originInstant = .now
        clock = BeatClock(startingAt: 0, bpm: tempo)
        beatIndex = 0
        if isCalibration {
            analyzer = nil
            phase = .calibrationQuiet(beatsLeft: Self.calibrationQuietBeats)
        } else {
            analyzer = TimingAnalyzer(
                beatZero: originHost + Double(Self.countIn) * interval,
                interval: interval,
                subdivision: subdivision.rawValue,
                offset: calibration ?? 0
            )
            phase = .countIn(beatsLeft: Self.countIn)
        }
        log.info("begin \(isCalibration ? "calibration" : "take", privacy: .public) at \(tempo) BPM, mic \(self.audio.sampleRate) Hz")
        runLoop()
    }

    func stop(reason: String?) {
        guard isRunning else { return }
        loop?.cancel()
        loop = nil
        audio.stop()
        session.end()
        if calibrating {
            phase = .idle
            message = reason ?? "Calibration cancelled."
        } else {
            summary = analyzer?.summary()
            phase = .summary
            message = reason
        }
        log.info("stop: \(reason ?? "tapped", privacy: .public), \(self.notesHeard) notes")
    }

    // MARK: - Beats

    private func runLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let due = self.originInstant + .seconds(self.clock.nextBeat)
                do {
                    try await Task.sleep(until: due, tolerance: .zero, clock: .suspending)
                } catch {
                    return
                }
                self.playBeat()
                if case .idle = self.phase { return }
            }
        }
    }

    private func playBeat() {
        let planned = originHost + clock.nextBeat
        let strong: Bool
        switch phase {
        case .countIn, .calibrationQuiet: strong = true
        default: strong = false
        }
        WKInterfaceDevice.current().play(strong ? .start : .click)
        beatTimes.append(planned)
        beatIndex += 1
        beatCount &+= 1
        clock.beatPlayed(at: (SuspendingClock.now - originInstant).inSeconds)
        advancePhase()
    }

    private func advancePhase() {
        switch phase {
        case .countIn:
            let left = Self.countIn - beatIndex
            phase = left > 0 ? .countIn(beatsLeft: left) : .listening
        case .calibrationQuiet:
            let left = Self.calibrationQuietBeats - beatIndex
            phase = left > 0 ? .calibrationQuiet(beatsLeft: left) : .calibrationPlay(beatsLeft: Self.calibrationPlayBeats)
        case .calibrationPlay:
            let left = Self.calibrationQuietBeats + Self.calibrationPlayBeats - beatIndex
            if left > 0 {
                phase = .calibrationPlay(beatsLeft: left)
            } else {
                phase = .calibrationPlay(beatsLeft: 0)
                // Let the last note's onset arrive (detector lookahead plus the audio buffer), then finish.
                loop?.cancel()
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(450))
                    self?.finishCalibration()
                }
            }
        default:
            break
        }
    }

    // MARK: - Onsets

    private func receive(_ found: [Double]) {
        guard isRunning else { return }
        onsets += found
        guard !calibrating, var analyzer else { return }
        for onset in found {
            if analyzer.add(onset: onset) != nil { notesHeard += 1 }
        }
        live = analyzer.recentDeviation()
        self.analyzer = analyzer
    }

    private func finishCalibration() {
        guard calibrating, isRunning else { return }
        let quiet = Array(beatTimes.prefix(Self.calibrationQuietBeats))
        let play = Array(beatTimes.dropFirst(Self.calibrationQuietBeats))
        audio.stop()
        session.end()
        phase = .idle
        if Calibration.hearsOwnTaps(onsets: onsets, silentBeats: quiet) {
            message = "The watch hears its own taps. Turn on Silent Mode, then calibrate again."
        } else if let offset = Calibration.offset(onsets: onsets, beats: play) {
            calibration = offset
            defaults.set(offset, forKey: Key.calibration)
            message = "Calibrated: you play \(TakeSummary.ms(abs(offset))) \(offset >= 0 ? "after" : "before") the tap. Saved."
        } else {
            message = "Didn't hear enough notes (6 of 8 needed). Play a bit louder, closer to the watch."
        }
        log.info("calibration: \(self.message ?? "", privacy: .public)")
    }

    // MARK: - App state

    func appMovedToBackground() {
        guard isRunning, !session.isActive else { return }
        stop(reason: "Stopped when you left")
    }

    private func microphoneAllowed() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}

private extension Duration {
    var inSeconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) * 1e-18
    }
}
