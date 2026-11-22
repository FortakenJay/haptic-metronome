/// One note matched to the beat grid.
public struct NoteTiming: Sendable, Equatable {
    /// Onset time, on the same clock as the beat times.
    public let time: Double
    /// Which subdivision of the grid it belongs to (0 = the first beat of the take).
    public let slot: Int
    /// Beat number within the take (slot / subdivision).
    public let beat: Int
    /// Seconds from the grid point after calibration: negative is early (rushing), positive is late (dragging).
    public let deviation: Double
}

/// Matches onsets to a beat grid and keeps every match, for the live needle and the end-of-take summary.
///
/// The grid starts at `beatZero` and has `subdivision` slots per beat (1 quarters, 2 eighths, 3 triplets,
/// 4 sixteenths). An onset belongs to the nearest slot if it is within `acceptFraction` of a slot from it;
/// anything further away (a grace note, an ornament, noise) is counted as unmatched and ignored.
public struct TimingAnalyzer: Sendable {
    public let beatZero: Double
    public let interval: Double
    public let subdivision: Int
    /// Calibration: the median of your onsets minus the beat when tapping along. Subtracted from every onset.
    public let offset: Double
    public let acceptFraction: Double

    public private(set) var notes: [NoteTiming] = []
    public private(set) var unmatched = 0

    public init(beatZero: Double, interval: Double, subdivision: Int, offset: Double = 0, acceptFraction: Double = 0.35) {
        precondition(interval > 0 && subdivision >= 1)
        self.beatZero = beatZero
        self.interval = interval
        self.subdivision = subdivision
        self.offset = offset
        self.acceptFraction = acceptFraction
    }

    public var slotLength: Double { interval / Double(subdivision) }

    /// Adds an onset; returns its timing if it matched the grid.
    @discardableResult
    public mutating func add(onset: Double) -> NoteTiming? {
        let t = onset - offset
        let slot = Int(((t - beatZero) / slotLength).rounded())
        let deviation = t - (beatZero + Double(slot) * slotLength)
        guard slot >= 0, abs(deviation) <= acceptFraction * slotLength else {
            if t >= beatZero - acceptFraction * slotLength { unmatched += 1 }
            return nil
        }
        let note = NoteTiming(time: onset, slot: slot, beat: slot / subdivision, deviation: deviation)
        notes.append(note)
        return note
    }

    /// Median deviation of the last `count` notes: what the live needle shows. Nil before any note.
    public func recentDeviation(last count: Int = 6) -> Double? {
        guard !notes.isEmpty else { return nil }
        return Stats.median(notes.suffix(count).map(\.deviation))
    }

    public func summary(beatsPerBar: Int = 4) -> TakeSummary {
        TakeSummary(notes: notes, unmatched: unmatched, subdivision: subdivision, beatsPerBar: beatsPerBar)
    }
}

/// The end-of-take report. All times are seconds; negative means early.
public struct TakeSummary: Sendable, Equatable {
    public let noteCount: Int
    public let unmatched: Int
    /// Median deviation of every matched note.
    public let median: Double?
    /// Robust spread (1.4826 × median absolute deviation): how steady the timing is.
    public let spread: Double?
    /// Median in beats with several notes (runs), and in beats with few (chords, melody).
    public let dense: Double?
    public let sparse: Double?
    /// The two-bar stretch whose median is furthest from zero, if it is at least `stretchThreshold` off.
    public let worstStretch: Stretch?

    public struct Stretch: Sendable, Equatable {
        /// First and last bar, counted from 1.
        public let firstBar: Int
        public let lastBar: Int
        public let median: Double
    }

    /// Below this, timing counts as on the beat.
    public static let onBeat = 0.010
    /// Runs and the rest must differ by at least this to call them out.
    public static let contrast = 0.015
    public static let stretchThreshold = 0.015

    public init(notes: [NoteTiming], unmatched: Int, subdivision: Int, beatsPerBar: Int) {
        noteCount = notes.count
        self.unmatched = unmatched
        let deviations = notes.map(\.deviation)
        median = Stats.median(deviations)
        spread = median.map { m in 1.4826 * Stats.median(deviations.map { abs($0 - m) })! }

        // A beat is dense when it has at least max(2, subdivision - 1) notes: 3 of 4 sixteenths, 2 eighths.
        let denseAt = max(2, subdivision - 1)
        var perBeat: [Int: [Double]] = [:]
        for note in notes { perBeat[note.beat, default: []].append(note.deviation) }
        let denseValues = perBeat.values.filter { $0.count >= denseAt }.flatMap { $0 }
        let sparseValues = perBeat.values.filter { $0.count < denseAt }.flatMap { $0 }
        dense = Stats.median(denseValues)
        sparse = Stats.median(sparseValues)

        var perStretch: [Int: [Double]] = [:]
        for note in notes { perStretch[note.beat / (2 * beatsPerBar), default: []].append(note.deviation) }
        // Earliest stretch wins unless a later one is at least 1 ms further off: ties (and float noise) never
        // depend on dictionary order.
        var worst: (Int, Double)?
        for (key, values) in perStretch.sorted(by: { $0.key < $1.key }) where values.count >= 4 {
            guard let value = Stats.median(values) else { continue }
            if worst == nil || abs(value) > abs(worst!.1) + 0.001 { worst = (key, value) }
        }
        if let worst, abs(worst.1) >= Self.stretchThreshold {
            worstStretch = Stretch(firstBar: worst.0 * 2 + 1, lastBar: worst.0 * 2 + 2, median: worst.1)
        } else {
            worstStretch = nil
        }
    }

    /// One sentence for the top of the summary.
    public var headline: String {
        guard let median else { return "No notes heard. Play closer to the watch, or check Silent Mode." }
        if let dense, let sparse, abs(dense - sparse) >= Self.contrast {
            let verb = dense < sparse ? "rush" : "drag"
            return "You \(verb) by \(Self.ms(abs(dense))) in the runs, \(Self.describe(sparse)) elsewhere."
        }
        if abs(median) < Self.onBeat { return "On the beat: within \(Self.ms(Self.onBeat)) overall." }
        return median < 0 ? "You rush by \(Self.ms(-median))." : "You drag by \(Self.ms(median))."
    }

    /// "12 ms early", "8 ms late", "on the beat".
    public static func describe(_ deviation: Double) -> String {
        if abs(deviation) < onBeat { return "on the beat" }
        return deviation < 0 ? "\(ms(-deviation)) early" : "\(ms(deviation)) late"
    }

    public static func ms(_ seconds: Double) -> String {
        "\(Int((seconds * 1000).rounded())) ms"
    }
}

/// Calibration: you tap along to the click while the watch listens.
///
/// The offset absorbs everything constant: the Taptic Engine's delay, the microphone's latency, the detector's
/// own timing bias, and how far ahead of the felt tap you naturally play. After calibrating, "on the beat" means
/// "where you play when you play with the click".
public enum Calibration {
    /// Offset from onsets while tapping along on `beats`. Uses onsets within 40 % of a beat of their nearest beat;
    /// needs at least `minimumHits` of them.
    public static func offset(onsets: [Double], beats: [Double], minimumHits: Int = 6) -> Double? {
        guard beats.count >= 2 else { return nil }
        let interval = (beats.last! - beats.first!) / Double(beats.count - 1)
        var deviations: [Double] = []
        for onset in onsets {
            guard let nearest = beats.min(by: { abs($0 - onset) < abs($1 - onset) }) else { continue }
            let d = onset - nearest
            if abs(d) <= 0.4 * interval { deviations.append(d) }
        }
        return deviations.count >= minimumHits ? Stats.median(deviations) : nil
    }

    /// True if the watch hears its own taps: during beats where you were told not to play, onsets turned up
    /// within 60 ms of at least half of them. The fix is Silent Mode (the tap's click sound is what it hears).
    public static func hearsOwnTaps(onsets: [Double], silentBeats: [Double]) -> Bool {
        guard !silentBeats.isEmpty else { return false }
        let hits = silentBeats.filter { beat in onsets.contains { abs($0 - beat) <= 0.060 } }.count
        return hits * 2 >= silentBeats.count
    }
}

enum Stats {
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}
