import SwiftUI

@main
struct TactusApp: App {
    /// App-scoped, so the metronome and its runtime session live exactly as long as the app. When the screen's
    /// own `@State` owned it, a view rebuild could release a running session, which watchOS logged as
    /// "WKExtendedRuntimeObject was dealloced while running" right before the beats went silent.
    @State private var metronome = Metronome()

    var body: some Scene {
        WindowGroup {
            MetronomeView(metronome: metronome)
        }
    }
}
