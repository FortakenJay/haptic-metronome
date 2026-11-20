/// Tempo rules: the range the crown can reach, the gap between beats, and the Italian marking for a speed.
///
/// Pure Swift, no WatchKit, so it is tested with `swift test` on a Mac.
public enum Tempo {
    /// Slowest and fastest tempo the crown can set, in beats per minute.
    public static let range = 30...240

    /// Tempo on first launch.
    public static let defaultBPM = 100

    /// Rounds a crown value to a whole BPM inside `range`.
    public static func clamped(_ value: Double) -> Int {
        guard value.isFinite else { return defaultBPM }
        let rounded = Int(value.rounded())
        return min(max(rounded, range.lowerBound), range.upperBound)
    }

    /// Seconds between two beats at `bpm`.
    public static func interval(for bpm: Int) -> Double {
        60.0 / Double(bpm)
    }

    /// The conventional Italian marking for a tempo. Sources disagree by a few BPM at every edge;
    /// these cutoffs are one common reading, made non-overlapping so every BPM gets exactly one name.
    public static func marking(for bpm: Int) -> String {
        switch bpm {
        case ..<40: "Grave"
        case ..<60: "Largo"
        case ..<66: "Larghetto"
        case ..<76: "Adagio"
        case ..<108: "Andante"
        case ..<120: "Moderato"
        case ..<156: "Allegro"
        case ..<176: "Vivace"
        case ..<200: "Presto"
        default: "Prestissimo"
        }
    }
}
