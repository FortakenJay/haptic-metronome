/// Where the beats fall on a timeline, in seconds since the metronome started.
///
/// Every beat is placed from the previous *planned* time, never from when the last buzz actually happened,
/// so a buzz that fires a few milliseconds late does not push every later beat late too. The clock never
/// reads a real clock itself: the caller passes `now`, which is what makes it testable.
public struct BeatClock: Equatable, Sendable {
    /// Seconds between beats at the current tempo.
    public private(set) var interval: Double

    /// When the next beat should play.
    public private(set) var nextBeat: Double

    /// A clock whose first beat is due at `time`.
    public init(startingAt time: Double, bpm: Int) {
        interval = Tempo.interval(for: bpm)
        nextBeat = time
    }

    /// Call right after the beat due at `nextBeat` has played.
    ///
    /// If the app was held up for longer than a beat (the system paused it, say), the beats that were
    /// missed are skipped rather than played late, so a stall never comes back as a burst of buzzes.
    public mutating func beatPlayed(at now: Double) {
        nextBeat += interval
        if nextBeat <= now {
            let missed = ((now - nextBeat) / interval).rounded(.down) + 1
            nextBeat += missed * interval
        }
    }

    /// Changes tempo without a jump: the next beat lands one *new* interval after the last one.
    public mutating func setTempo(_ bpm: Int) {
        let lastBeat = nextBeat - interval
        interval = Tempo.interval(for: bpm)
        nextBeat = lastBeat + interval
    }
}
