import os
import WatchKit

/// Tactus's own lines in the Xcode console and Console.app (subsystem `com.fortakenjay.tactus`).
private let sessionLog = Logger(subsystem: "com.fortakenjay.tactus", category: "session")

/// Keeps Tactus running, and buzzing, after the wrist drops and the screen goes dark.
///
/// Without this, watchOS suspends the app a moment after the wrist comes down and the beats stop. The session
/// type is *mindfulness* (set under `WKBackgroundModes` in `Support/Info.plist`): it keeps the app frontmost
/// with the screen off for up to one hour, and ends early if you press the crown or open another app.
@MainActor
final class RuntimeSession: NSObject {
    enum End {
        /// The one-hour limit was reached.
        case expired
        /// The system or the user ended it early (crown press, another app's session, an error).
        case interrupted
    }

    /// Called once when a session ends on its own. Never called after `end()`.
    var onEnd: (@MainActor (End) -> Void)?

    private var session: WKExtendedRuntimeSession?

    /// True from `begin()` until the session ends or `end()` is called.
    var isActive: Bool { session != nil }

    /// Starts a session. Must be called while the app is active, which it is: the user just tapped.
    func begin() {
        guard session == nil else { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        session = newSession
        sessionLog.info("begin: start requested")
    }

    /// Ends the session because the user stopped the metronome.
    ///
    /// Invalidates in every state except `.invalid`, including `.notStarted`: `start()` is asynchronous, so a
    /// quick start-stop (or a simulator, where the session may never reach `.running`) can catch it before it
    /// runs. Releasing a started session without invalidating it makes watchOS log "dealloced while running".
    func end() {
        guard let current = session else { return }
        session = nil   // forget it first, so its own invalidation callback is ignored
        let state = current.state.rawValue
        sessionLog.info("end: state \(state)")
        if current.state != .invalid {
            current.invalidate()
        }
    }

    private func finish(_ id: ObjectIdentifier, _ end: End) {
        guard let current = session, ObjectIdentifier(current) == id else { return }
        session = nil
        onEnd?(end)
    }
}

extension RuntimeSession: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        sessionLog.info("did start")
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        sessionLog.notice("will expire")
        let id = ObjectIdentifier(extendedRuntimeSession)
        Task { @MainActor in self.finish(id, .expired) }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        // Reasons: 0 none, 1 another session in progress, 2 expired, 3 left the app, 4 suppressed by system, -1 error.
        sessionLog.notice("invalidated: reason \(reason.rawValue), error \(error?.localizedDescription ?? "none", privacy: .public)")
        let id = ObjectIdentifier(extendedRuntimeSession)
        let end: End = reason == .expired ? .expired : .interrupted
        Task { @MainActor in self.finish(id, end) }
    }
}
