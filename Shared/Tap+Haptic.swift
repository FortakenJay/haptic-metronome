import WatchKit

extension Tap {
    /// The Taptic Engine pattern for this tap. `.click` is the lightest tick watchOS has; `.start` is a firmer
    /// single tap. Both also play a short sound unless the watch is in Silent Mode.
    var haptic: WKHapticType {
        switch self {
        case .light: .click
        case .strong: .start
        }
    }
}
