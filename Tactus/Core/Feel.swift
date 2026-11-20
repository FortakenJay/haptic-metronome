/// How strong each beat feels on the wrist. The mapping to a real Taptic Engine pattern lives in the app
/// layer (`Feel+Haptic.swift`), so this file stays free of WatchKit.
public enum Feel: String, CaseIterable, Sendable {
    case light
    case strong

    /// The other feel; the toolbar button flips between the two.
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
}
