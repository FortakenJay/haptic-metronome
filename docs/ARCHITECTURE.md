# Tactus: Architecture

Status: **v1.1** (2026-11-21). Two watch-only apps from one project: **Tactus** (metronome, with meters) and
**Tactus Lab** (rushing/dragging detector). Minimum watchOS 26.6 (the code needs 10). 34 tests (`swift test`); both
apps are built by GitHub Actions on every push. Not yet felt on hardware at every tempo, and Lab not yet measured
on a real piano (see *Open* at the end).

## Layers

```
Core/                         plain Swift, no WatchKit, in both apps, tested by `swift test`
├── Tempo.swift               range 30–240, rounding, 60/BPM, Italian markings
├── BeatClock.swift           the schedule: nextBeat, beatPlayed(at:), setTempo(_:)
├── Feel.swift                Tap (light | strong), Feel (light | strong)
└── Meter.swift               time signatures, groupings, accents, tap(atBeat:feel:)
Shared/                       WatchKit, in both apps
├── RuntimeSession.swift      WKExtendedRuntimeSession (mindfulness) wrapper
└── Tap+Haptic.swift          Tap → WKHapticType
Tactus/                       the metronome app
├── TactusApp.swift           @main; owns the Metronome
├── Metronome.swift           @Observable @MainActor: play state, beat loop, meter position, saved settings
├── MetronomeView.swift       the one screen
├── MeterPicker.swift         time signature list
└── BeatDots.swift            the bar, grouped
LabCore/                      plain Swift + Accelerate, Lab only, tested by `swift test`
├── OnsetDetector.swift       streaming spectral-flux onset detector
└── TimingAnalyzer.swift      grid matching, TakeSummary, Calibration
Lab/                          the Tactus Lab app
├── LabApp.swift              @main; owns the LabSession
├── LabSession.swift          count-in, click, takes, calibration
├── AudioInput.swift          AVAudioEngine microphone tap → OnsetDetector (audio thread)
├── LabView.swift, TimingNeedle.swift, SummaryView.swift
Support/Info.plist            Tactus: WKApplication, WKBackgroundModes = [mindfulness]
Support/Lab-Info.plist        Lab: + audio background mode, microphone usage text
Package.swift                 test-only package: TactusCore (Core/), LabCore (LabCore/)
Tests/TactusCoreTests/        BeatClock (6), Tempo (6), Meter (7)
Tests/LabCoreTests/           OnsetDetector (6), TimingAnalyzer (9), synthetic piano generator
research/onset-prototype/     the Python prototype the detector was tuned with
```

**The rule:** anything that decides *when* or *what* goes in `Core/` or `LabCore/`, takes its inputs as
arguments, and gets a test. The app layers only connect those decisions to WatchKit, AVFoundation and SwiftUI.
Each Xcode target compiles its folders directly (one module per app), and `Package.swift` compiles `Core/` and
`LabCore/` as two modules for tests. **Tactus and Lab share only `Core/` and `Shared/`**: Lab has its own engine,
so nothing done for Lab can change how the metronome behaves.

## State

`Metronome` is the only state holder. `TactusApp` owns it (`@State` at app scope) and hands it to the view, so a
view rebuild can never release it or its running session. The view reads it and calls its methods, plus
`appBecameActive()` / `appMovedToBackground()` from `scenePhase`.

| Property | Type | Saved | Read by |
|---|---|---|---|
| `bpm` | `Int`, 30–240 | `UserDefaults` `tempo.bpm` | dial, crown binding, accessibility value |
| `feel` | `Feel` | `UserDefaults` `tempo.feel` | toolbar button, `playBeat()` (meter Off only) |
| `meter` | `Meter` | `UserDefaults` `tempo.meter` (id, e.g. `7/8:2+2+3`) | meter button, picker, dots, subtitle, `playBeat()` |
| `beatInBar` | `Int` | no | beat dots |
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
| any | meter picked | same | save `meter`; the next beat is beat 1 of a bar |
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
