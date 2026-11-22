import SwiftUI

/// Tactus Lab: the experimental twin of Tactus that listens to your piano and measures rushing and dragging.
/// A separate app on purpose, so experiments here never touch the metronome you practise with.
@main
struct TactusLabApp: App {
    @State private var lab = LabSession()

    var body: some Scene {
        WindowGroup {
            LabView(lab: lab)
        }
    }
}
