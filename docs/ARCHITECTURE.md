# Tactus: Architecture

Status: **v1.0** (2026-11-20). One watch-only target, minimum watchOS 26.6 (the code needs 10). 12 core tests (`swift test`); the watch app is
built by GitHub Actions on every push. Not yet felt on hardware at every tempo (see *Open* at the end).

## Layers

```
Tactus/
├── Core/                     plain Swift, no WatchKit, tested by `swift test`
│   ├── Tempo.swift           range 30–240, rounding, 60/BPM, Italian markings
│   ├── BeatClock.swift       the schedule: nextBeat, beatPlayed(at:), setTempo(_:)
│   └── Feel.swift            light | strong
├── Metronome.swift           @Observable @MainActor: play state, beat loop, saved settings
├── RuntimeSession.swift      WKExtendedRuntimeSession (mindfulness) wrapper
├── Feel+Haptic.swift         Feel → WKHapticType
├── MetronomeView.swift       the one screen
└── TactusApp.swift           @main
Support/Info.plist            WKApplication, WKBackgroundModes = [mindfulness]
Package.swift                 test-only package over Tactus/Core
Tests/TactusCoreTests/        BeatClockTests (6), TempoTests (6)
```

**The rule:** anything that decides *when* or *what* goes in `Core/`, takes its inputs as arguments, and gets a
test. The app layer only connects those decisions to WatchKit and SwiftUI. The Xcode target compiles `Core/`
directly (same module), and `Package.swift` compiles the same files as `TactusCore` for tests.

## State

`Metronome` is the only state holder. `TactusApp` owns it (`@State` at app scope) and hands it to the view, so a
view rebuild can never release it or its running session. The view reads it and calls its methods, plus
`appBecameActive()` / `appMovedToBackground()` from `scenePhase`.

| Property | Type | Saved | Read by |
|---|---|---|---|
| `bpm` | `Int`, 30–240 | `UserDefaults` `tempo.bpm` | dial, crown binding, accessibility value |
| `feel` | `Feel` | `UserDefaults` `tempo.feel` | toolbar button, `playBeat()` |
| `isPlaying` | `Bool` | no | ring colour, status label, crown detent haptics |
| `beatCount` | `Int` | no | ring flash trigger |
| `notice` | `String?` | no | status, accessibility value |

Not observed (`@ObservationIgnored`): `clock`, `origin`, `loop`, `session`, `defaults`.

## States and transitions

| From | Event | To | Side effects |
|---|---|---|---|
| Stopped | tap | Playing | `notice = nil`; `origin = now`; new `BeatClock` (first beat at 0 s); `session.begin()`; start loop |
| Playing | tap | Stopped | cancel loop; `session.end()` (forget, then invalidate) |
| Playing | crown / VoiceOver adjust | Playing | `clock.setTempo`; restart loop; save `bpm` |
| Stopped | crown / VoiceOver adjust | Stopped | save `bpm` |
| any | feel button | same | save `feel`; play a sample if Stopped |
| Playing | session `expired` | Stopped | `notice = "Stopped after an hour"` |
| Playing | session `interrupted`, app active, tries left | Playing | `session.begin()` again (3 tries per run) |
| Playing | session `interrupted`, app not active or no tries left | Stopped | `notice = "watchOS ended the session"` |
| Playing, no session | scene `.active` | Playing | `session.begin()` |
| Playing, no session | scene `.background` | Stopped | `notice = "Stopped when you left"` |

`start()` and `stop()` both check the current state first, so calling one twice does nothing.

## Invariants

1. **Beat *n* is due at `origin + Σ intervals`**, never at "last fire + interval". (`BeatClock.beatPlayed`)
2. **No bursts.** After every played beat, `nextBeat > now`, however late that beat was. (`BeatClock.beatPlayed`)
3. **No tempo jump.** After `setTempo`, `nextBeat − lastBeat == newInterval`. (`BeatClock.setTempo`)
4. **At most one loop.** `runLoop()` cancels the previous `Task` before starting another.
5. **Playing means a session or an active app.** If the session is gone, either a new one starts (app active) or
   the metronome stops with a notice. Never "playing" with nobody keeping the app alive.
6. **At most one session**, and a session ended by the user never calls back into `Metronome`
   (`RuntimeSession.end` clears `session` before `invalidate()`; `finish` checks identity).
7. **The ring flash (0.21 s) is shorter than the shortest beat (0.25 s at 240 BPM).**

## Concurrency

Everything that changes state runs on the main actor: `Metronome` and `RuntimeSession` are `@MainActor`, and the
beat loop is a `Task` started from the main actor, so it resumes there after each sleep. The session's delegate
callbacks are `nonisolated` and pass only the session's `ObjectIdentifier` to the main actor in a `Task`.

## Open

- Haptic feel at fast tempos on real hardware: when does Strong (`.start`) stop being distinct from the next beat?
- Screenshots of each watch size for the README.
- Accents / time signature and tap tempo (README, *What it doesn't do yet*).
