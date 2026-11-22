/// A time signature and how its beats are grouped, which decides which beats of a bar are accented.
///
/// `5/8` grouped `3+2` taps STRONG light light STRONG light: the first beat of every group is accented.
/// The tempo always counts the bottom number's note, so in /8 meters it is eighth notes per minute.
public struct Meter: Hashable, Sendable, Identifiable {
    /// Top number: beats in a bar.
    public let beats: Int
    /// Bottom number: 4 (quarter notes) or 8 (eighth notes).
    public let unit: Int
    /// Group sizes, summing to `beats`. One group means only beat 1 is accented.
    public let groups: [Int]
    /// No meter: every beat is the same, with the strength the Feel button sets.
    public let isOff: Bool

    public init(_ beats: Int, _ unit: Int, groups: [Int]? = nil) {
        precondition(beats > 0 && (unit == 4 || unit == 8), "meter \(beats)/\(unit)")
        let groups = groups ?? [beats]
        precondition(groups.allSatisfy { $0 > 0 } && groups.reduce(0, +) == beats, "groups \(groups) for \(beats)")
        self.beats = beats
        self.unit = unit
        self.groups = groups
        self.isOff = false
    }

    private init(off: Void) {
        beats = 1
        unit = 4
        groups = [1]
        isOff = true
    }

    /// No accents.
    public static let off = Meter(off: ())

    /// The meters the picker offers, plain ones first, then the odd ones with their usual groupings.
    public static let all: [Meter] = [
        .off,
        Meter(2, 4), Meter(3, 4), Meter(4, 4),
        Meter(5, 4, groups: [3, 2]), Meter(5, 4, groups: [2, 3]),
        Meter(6, 8, groups: [3, 3]),
        Meter(5, 8, groups: [3, 2]), Meter(5, 8, groups: [2, 3]),
        Meter(7, 8, groups: [2, 2, 3]), Meter(7, 8, groups: [3, 2, 2]), Meter(7, 8, groups: [2, 3, 2]),
        Meter(9, 8, groups: [2, 2, 2, 3]), Meter(9, 8, groups: [3, 3, 3]),
        Meter(11, 8, groups: [3, 3, 3, 2]),
        Meter(12, 8, groups: [3, 3, 3, 3]),
    ]

    /// Stable identifier for saving the choice: "off", "4/4", "7/8:2+2+3".
    public var id: String {
        if isOff { return "off" }
        return groups.count > 1 ? "\(label):\(groupingLabel!)" : label
    }

    /// The meter with this `id`, if it is one of `all`.
    public static func with(id: String) -> Meter? {
        all.first { $0.id == id }
    }

    /// "5/8", or "Off".
    public var label: String {
        isOff ? "Off" : "\(beats)/\(unit)"
    }

    /// "3+2" when the bar has more than one group, otherwise nil.
    public var groupingLabel: String? {
        groups.count > 1 ? groups.map(String.init).joined(separator: "+") : nil
    }

    /// What VoiceOver says: "5/8, 3 plus 2".
    public var spokenLabel: String {
        guard groups.count > 1 else { return label }
        return "\(label), \(groups.map(String.init).joined(separator: " plus "))"
    }

    /// True for /8 meters, where the tempo counts eighth notes.
    public var countsEighths: Bool {
        unit == 8
    }

    /// Indices within the bar where a group starts: [0, 3] for 3+2.
    public var groupStarts: [Int] {
        var starts: [Int] = []
        var position = 0
        for size in groups {
            starts.append(position)
            position += size
        }
        return starts
    }

    public enum Accent: Sendable, Equatable {
        /// Beat 1 of the bar.
        case downbeat
        /// The first beat of a later group.
        case group
        /// Any other beat.
        case plain
    }

    /// Where beat number `index` (counted from the start, 0-based) falls in its bar.
    public func position(ofBeat index: Int) -> Int {
        let r = index % beats
        return r < 0 ? r + beats : r
    }

    public func accent(atBeat index: Int) -> Accent {
        if isOff { return .plain }
        let p = position(ofBeat: index)
        if p == 0 { return .downbeat }
        return groupStarts.contains(p) ? .group : .plain
    }

    /// The tap for beat `index`: with a meter, group starts are strong and the rest light; with no meter,
    /// every beat follows `feel`. Two strengths are all watchOS gives, so beat 1 and later group starts tap the
    /// same; the screen's beat dots show where the bar begins.
    public func tap(atBeat index: Int, feel: Feel) -> Tap {
        if isOff { return feel.tap }
        return accent(atBeat: index) == .plain ? .light : .strong
    }
}
