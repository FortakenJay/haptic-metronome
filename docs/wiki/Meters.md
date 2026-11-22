# Meters

A time signature in Tactus is two numbers and a grouping. The grouping is what makes an odd meter feel like
itself: 7/8 counted 2+2+3 and 7/8 counted 3+2+2 are different pieces of music.

## What taps

| Meter | Grouping | Taps (S = Strong, l = Light) |
|---|---|---|
| Off | | every beat the same, with the Feel button's strength |
| 4/4 | | S l l l |
| 5/4 | 3+2 | S l l S l |
| 6/8 | 3+3 | S l l S l l |
| 5/8 | 3+2 | S l l S l |
| 5/8 | 2+3 | S l S l l |
| 7/8 | 2+2+3 | S l S l S l l |
| 7/8 | 3+2+2 | S l l S l S l |
| 9/8 | 2+2+2+3 | S l S l S l S l l |
| 11/8 | 3+3+3+2 | S l l S l l S l l S l |

The full list is `Meter.all` in `Core/Meter.swift`: 16 entries including Off.

- **The first beat of every group taps Strong.** Feeling a 7/8 means feeling where the groups start. Those are
  the taps you count on.
- **Beat 1 and a later group start feel the same.** watchOS gives two strengths of tap (`.start` and `.click`),
  not three. The beat dots under the dial show where the bar starts: beat 1's dot is the largest, and dots are
  spaced by group, so 2+2+3 reads as ●○ ○○ ○○○.
- **The Feel button only applies with no meter.** With a meter, the pattern is fixed, so the button is disabled
  and says so to VoiceOver.

## What the number counts

The tempo always counts the bottom number's note. In 4/4 it's quarter notes per minute, as usual. In 5/8 or 7/8
it's **eighth notes** per minute, so 7/8 at 210 taps every eighth note, 210 times a minute. The label under the
number reads `BPM ♪` in /8 meters.

The Italian marking (Andante, Allegro) is shown only for /4 meters. For /8 meters the grouping replaces it.
"Prestissimo" for an eighth-note count would be wrong about how fast the music feels.

The range is the same 30 to 240. At 240 eighths a minute a tap comes every 0.25 s, about as fast as two taps stay
distinct on the wrist.

## Changing meter while playing

The next beat becomes beat 1 of a new bar, so you never land mid-bar in a meter you just chose. The tempo and the
beat timing carry on unchanged.

## Code

| Piece | Where |
|---|---|
| Meter model, accents, taps, labels | `Core/Meter.swift` (7 tests in `Tests/TactusCoreTests/MeterTests.swift`) |
| `Tap` and `Feel` | `Core/Feel.swift` |
| Tap → Taptic pattern | `Shared/Tap+Haptic.swift` |
| Beat position, saved meter | `Tactus/Metronome.swift` (`meter`, `beatInBar`, `setMeter`) |
| Picker | `Tactus/MeterPicker.swift` |
| Beat dots | `Tactus/BeatDots.swift` |
