/// One tap on the wrist. The app layer maps it to a real Taptic Engine pattern (`Shared/Tap+Haptic.swift`),
/// so this file stays free of WatchKit.
public enum Tap: Sendable, Equatable {
    /// The lightest tick watchOS has.
    case light
    /// A firmer single tap.
    case strong
}

/// How strong every beat feels when no meter is set. The toolbar button flips between the two.
public enum Feel: String, CaseIterable, Sendable {
    case light
    case strong

    /// The other feel.
    public var next: Feel {
        self == .light ? .strong : .light
    }

    /// Word shown and read aloud for this feel.
    public var name: String {
        switch self {
        case .light: "Light"
        case .strong: "Strong"
        }
    }

    /// The tap every beat gets with this feel.
    public var tap: Tap {
        switch self {
        case .light: .light
        case .strong: .strong
        }
    }
}
