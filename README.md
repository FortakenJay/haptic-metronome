# Tactus

**A metronome you feel instead of hear, on Apple Watch.**

[![build](https://github.com/FortakenJay/haptic-metronome/actions/workflows/build.yml/badge.svg)](https://github.com/FortakenJay/haptic-metronome/actions/workflows/build.yml)

<p align="center">
  <img src="docs/img/hero.png" alt="Tactus on a 46 mm Apple Watch: stopped at 100 BPM, Andante, and playing at 120 BPM, Allegro, with the amber ring lit on a beat" width="600">
</p>

<sub>Watch simulator, Series 10 (46 mm). Left: stopped. Right: playing, caught on a beat. The red icon next to the clock is the
simulator saying no iPhone is connected; it isn't part of the app.</sub>

---

## A click you don't have to hear

A metronome click has to compete with the instrument. Play loud and you lose it. Play quietly and it's the
loudest thing in the room. Put it in headphones and it ends up in the recording. Every option means you end up
listening to the click instead of to yourself.

A tap on the wrist doesn't have that problem. Nobody else can hear it, it doesn't fight the sound you're making,
and you still notice it when your ears are busy.

*Tactus* is the old word for the beat in Renaissance music theory, and Latin for *touch*.

## What it does

**1. Turn the crown to set the tempo.** Turning the crown moves the tempo one BPM at a time, from 30 to 240. The
number changes immediately. Under it is the tempo's Italian name (Andante at 100, Allegro at 120), so you can
match a marking on the page without doing arithmetic.

**2. Tap anywhere to start.** The whole screen is the button. The first beat plays the moment you tap. Tap again
to stop.

**3. Every beat taps your wrist.** The ring lights up in time. While it plays, the crown's detent clicks are
switched off, so the only taps you feel are beats.

**4. Lower your wrist and it keeps going.** Tactus runs a watchOS *mindfulness* session, which keeps the app
running with the screen off for up to an hour. If it stops on its own, the screen says why and that a tap
restarts it.

**5. Pick how hard it taps.** The hand button at the top switches between **Light** (watchOS's lightest click)
and **Strong** (a firmer single tap). When the metronome is stopped, switching plays a sample beat.

**6. It remembers.** Tempo and feel are saved, so it opens where you left off.

| | |
|---|---|
| Tempo range | **30 to 240 BPM**, one BPM per crown detent |
| First beat | Immediately on tap |
| With the wrist down | Keeps going **up to 1 hour** (watchOS limit for this session type) |
| Network, accounts, Health data | **None.** Nothing leaves the watch |

## The timing

Each beat is scheduled from the time it was *supposed* to play, not from when the last buzz actually played.
If every buzz fires 30 ms late, beat 1,000 at 120 BPM is still due at exactly 500.000 s instead of 30 seconds
late. A test checks this.

Two more rules, both tested:

- **A stall skips beats instead of bunching them.** If watchOS holds the app up for longer than a beat, the beats
  it missed are dropped and the next one lands back on the grid. They never come out as a burst of buzzes.
- **A tempo change takes effect on the next beat.** The next beat comes one *new* interval after the last one, so
  turning the crown mid-bar never doubles up or skips a beat.

What the code can't control is the Taptic Engine itself. The schedule is exact, but each tap lands whenever the
hardware fires it. That's fine for practice. It isn't a sample-accurate click for syncing a recording.
[How it works](docs/wiki/How-it-works.md) has the details.

## Run it on your own watch (free)

You need a Mac with **Xcode 16 or later**, an Apple Watch on **watchOS 26.6 or later**, and the iPhone it's paired
with. You don't need a paid developer account.

1. Open `Tactus.xcodeproj`.
2. Select the **Tactus** target, go to **Signing & Capabilities**, and under **Team** choose your Apple ID
   (*Personal Team*). If Xcode says the bundle identifier is taken, change `com.fortakenjay.tactus` to anything
   unique.
3. Turn on **Developer Mode** on the iPhone and on the watch (Settings → Privacy & Security). The option shows
   up after the device has been connected to Xcode once.
4. Pick the **Tactus** scheme and your Apple Watch as the destination, then press **Run**.

With a free Apple ID, Xcode's signing lasts **7 days**. After that the app won't open, so plug the iPhone in and
press Run again. A paid Apple Developer account makes an install last a year.
[Running it](docs/wiki/Running.md) lists the usual errors.

The timing logic has its own tests, which run without a watch:

```bash
swift test        # 12 tests: tempo rules and the beat clock
```

GitHub Actions builds the watch app and runs these tests on every push.

## Inside

SwiftUI and Observation for the screen, WatchKit for the haptics and the background session. The project is split
into two layers, and the split is the point:

- **`Tactus/Core/`** is plain Swift: tempo rules (`Tempo`), the beat schedule (`BeatClock`) and the two feels
  (`Feel`). It never reads a real clock and never imports WatchKit, so the rules that matter run under
  `swift test` on any Mac.
- **The app layer** is small: `Metronome` sleeps until each planned beat and plays it, `RuntimeSession` keeps the
  app running with the wrist down, and `MetronomeView` is the one screen.

The same screen on a 40 mm, 46 mm and 49 mm watch:

<p align="center">
  <img src="docs/img/sizes.png" alt="Tactus playing at 120 BPM on a 40 mm Apple Watch SE, a 46 mm Series 10 and a 49 mm Ultra 2" width="720">
</p>

| File | Job |
|---|---|
| `Tactus/Core/Tempo.swift` | Range, rounding, seconds per beat, Italian markings |
| `Tactus/Core/BeatClock.swift` | When the next beat is due; skipping after a stall; tempo changes without a jump |
| `Tactus/Core/Feel.swift` | Light and Strong |
| `Tactus/Metronome.swift` | Play state, the beat loop, saved settings |
| `Tactus/RuntimeSession.swift` | The mindfulness session that keeps the app running with the screen off |
| `Tactus/MetronomeView.swift` | Crown, tap, ring, labels, accessibility |
| `Tactus/Feel+Haptic.swift` | Light → `.click`, Strong → `.start` |

- [How it works](docs/wiki/How-it-works.md): the beat loop, the clock, the session, start to finish
- [Interface](docs/wiki/Interface.md): the interaction and accessibility rules the screen follows, and where each lives
- [Decisions](docs/wiki/Decisions.md): what was chosen over what, and why, by component
- [Running it](docs/wiki/Running.md): setup and troubleshooting
- [Knowledge graph](docs/wiki/Knowledge-graph.md): a map of the code (179 nodes), built with graphify
- [Architecture](docs/ARCHITECTURE.md): states, data flow, invariants

## What it doesn't do yet

- **Accents.** Every beat feels the same; there's no stronger beat 1 and no time signature yet.
- **Tap tempo.** No way yet to set the tempo by tapping it in.
- **More than an hour with the wrist down.** That's the cap for a mindfulness session. A workout session has no cap,
  but watchOS allows only one workout at a time, so it would end your run in the Workout app. Not worth it for a
  practice tool.
- **Measured on real hardware.** It hasn't been measured yet how fast the two feels stay distinct before they blur
  together near 240 BPM. If Strong blurs at fast tempos, use Light.

## How this was built

Jih designed it: the crown sets the tempo, a tap starts it, the beat is a haptic. Claude wrote the code, the tests
and this documentation from that design, following the interface rules in [Interface](docs/wiki/Interface.md).
Every number in this README comes from the code or its tests.
