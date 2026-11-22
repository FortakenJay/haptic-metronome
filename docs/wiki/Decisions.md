# Decisions, by component

What was chosen, what it was chosen over, and why.

## Project and platform

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| App shape | Watch-only app, one target | iPhone app with a watch extension | Nothing on the phone has a job. One target is less to sign and less to install |
| Minimum watchOS | 26.6 in the project; the code needs 10 | 10.0 | Set to match Jih's watch (26.6). Nothing in the code needs 26: `@Observable`, `keyframeAnimator`, `focusEffectDisabled` and top-bar toolbar items need 10. To run on an older watch, lower *Minimum Deployments* on the Tactus target. The screenshot workflow builds with 10.0 because GitHub's newest watch simulator is 26.2 |
| Xcode project format | Folder-synced groups (Xcode 16) | A file list in the project | New Swift files in `Tactus/` are picked up without editing `project.pbxproj` |
| Distribution | Free Personal Team, re-run every 7 days | Paid Apple Developer account | It's a personal tool. Paying only makes sense for the App Store or TestFlight |
| Checking the build | GitHub Actions on a macOS runner | Only building on a laptop | Every push gets the same compiler and the same tests, whoever wrote it |

## Timing

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| What sets each beat | The planned time of the previous beat + interval | Time the last buzz fired + interval | Lateness doesn't accumulate. Tested over 1,000 beats with 30 ms of lateness each |
| How the loop waits | `Task.sleep(until:)` to an absolute `ContinuousClock` instant, zero tolerance | `Timer` with a repeat interval | A `Timer` runs on the run loop, drifts, and has to be rebuilt on every tempo change anyway. An absolute deadline doesn't drift |
| After a stall | Skip missed beats, land back on the grid | Play the missed beats right away | Five buzzes in a burst is worse than a gap |
| Tempo change while playing | Next beat one *new* interval after the last | Restart from beat 0 now | Turning the crown mid-bar shouldn't double a beat or reset the bar |
| Where the timing rules live | `BeatClock`, pure Swift, takes `now` as an argument | Inside the class that plays the haptic | Testable on a Mac with `swift test`, no watch and no waiting |
| Tempo range | 30 to 240 BPM, whole numbers | 20 to 300, or fractions | Covers Grave to Prestissimo. At 240 a beat is 0.25 s, about as fast as a wrist tap stays distinct |

## Running with the wrist down

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| Keep-alive | `WKExtendedRuntimeSession`, mindfulness | `HKWorkoutSession` | A workout session has no hour cap, but watchOS runs one workout at a time, so starting it would end a real workout in another app. It also needs HealthKit and counts toward your rings |
| Session type | Mindfulness (frontmost, 1 hour) | Physical therapy (background, 1 hour) | The metronome only matters while you're in it. Frontmost ends when you leave, which is the honest behaviour |
| Session ends early while active | Start a fresh session (up to 3 times per run) | Keep playing without one | Tried first: it froze on Jih's watch. Without a session, the next wrist-down makes watchOS refuse the haptics, so taps and screen both stop while the app still says *playing* |
| Who owns the metronome | `TactusApp`, app-scoped `@State` | The screen's `@State` | A view rebuild released a running session ("dealloced while running" in the log). The session must live as long as the app |
| Diagnostics | `os.Logger`, subsystem `com.fortakenjay.tactus` | `print` | Shows in Console.app without Xcode attached, with the session's end reason |
| Session ends after you left | Stop and say why | Pretend it's still playing | The loop can't run while suspended, so a "playing" screen would be lying |

## Haptics

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| Patterns | Light = `.click`, Strong = `.start` | One fixed pattern | How strong a tap you can feel depends on the watch fit and how loud you're playing. Two is enough to choose from |
| Haptic API | `WKInterfaceDevice.play` | Core Haptics custom patterns | Core Haptics isn't available on watchOS |
| Sound | Leave the system sound on (it follows Silent Mode) | Try to suppress it | The watch decides. Silent Mode gives haptic only, which is the main use |

## Interface

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| Inputs | Crown = tempo, tap anywhere = start/stop | Buttons for + / − and play | Jih's design. Both work by feel, without looking |
| Tempo readout | Number + Italian marking | Number only | Sheet music says *Allegro*, not 132 |
| Number animation | None | Rolling digits | The crown is turned dozens of times in a row; animating every change makes it lag behind your fingers |
| Beat visual | Ring flash, 0.21 s | Full-screen flash | Visible from the corner of the eye, doesn't overlap even at 240 BPM, and the ring isn't drawn at all in Always On |
| Feel control | One toolbar button, outline/fill | A settings screen | Two options don't need a screen |
| Crown detent clicks | Off while playing | Always on | The only taps on the wrist while playing should be beats |

## Meters

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| Which beats are accented | The first beat of every group | Only beat 1 | Odd meters are felt by their groups: 7/8 as 2+2+3 is three pulses, not seven |
| Number of strengths | Two (Strong `.start`, Light `.click`), beat 1 shown by the dots | A third strength | watchOS has no third tap that is reliably distinct; two quick taps in a row risk the Taptic Engine refusing the second |
| /8 tempo | Counts eighth notes | Counts the group pulse | Eighths are what a score's marking usually gives for 5/8 and 7/8, and every eighth taps (Jih's choice) |
| Italian marking in /8 | Hidden; the grouping shows instead | Marking of the eighth count | "Prestissimo" for 240 eighths a minute would mislead |
| Feel with a meter | Disabled, says why | Feel sets the light beats | Strong light beats would erase the grouping |
| Meter change while playing | Next beat is beat 1 | Keep the bar position | A new meter mid-bar has no sensible "position" |
| Meter list | 16 curated entries with groupings | A free-form editor | Covers what piano repertoire uses; a watch is a poor place to type 2+2+2+3 |

## Tactus Lab

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| Where it lives | A second app in the same repo, sharing `Core/` and `Shared/` | Inside Tactus, or a separate repo | Jih wants the practice metronome untouched by experiments; sharing the tested core avoids a copy |
| Its engine | Its own `LabSession` | Reusing `Metronome` | Lab needs beat times on the audio clock and different phases; changes for Lab must not reach the metronome |
| Onset detection | Spectral flux above 1 kHz | Amplitude envelope; a trained model | Flux is the standard for percussive onsets; the band ignores the Taptic buzz; no model to ship or train |
| Tuning | Python prototype on synthetic takes first, then a Swift port with the same tests | Tuning on the watch | Known ground truth, seconds per experiment instead of a build and install |
| Timing precision | Frame centre + parabolic interpolation | Time-domain attack search | Tried first: it was 9 ms late with a 20 ms spread. The parabola gives ~1 ms spread |
| Loudness | Level normalisation | Fixed gain | The mic's level depends on the room and where the hand is; results now don't |
| Clock | Host clock for audio and beats; `SuspendingClock` to sleep | `ContinuousClock` like Tactus | Audio buffers are stamped on the host clock; both must be the same clock |
| Constant delays | One calibration offset | Modelling each delay | Haptic delay, mic latency, detector bias and your own habit are all constant; one median removes them together |
| Feedback | Live needle + summary | Summary only | Jih's choice: see it while playing, read it after |
| Statistics | Medians and MAD | Means and standard deviation | A wrong note or a missed one shouldn't move the verdict |
| The watch hearing itself | Checked during calibration; Silent Mode required | Filtering the click out | The click lands exactly on the beat, so filtering it would also remove on-beat notes |

## Docs and graph

| Decision | Chosen | Instead of | Why |
|---|---|---|---|
| Screenshots | Watch simulator on a GitHub runner, driven by launch arguments and a Debug-only autostart | A UI-test target that taps the screen | One script and no second target in the project. The cost is the flaky states listed in *Running it* |
| Graph | `docs/graph/` from graphify's syntax-tree pass (no AI service) | No graph, or an LLM-built one | Same as MarsWalk. Reproducible with `graphify update .` |
| Docs | README + `docs/wiki/` + `docs/ARCHITECTURE.md` | One long README | The README is the story; the wiki holds the details for whoever needs them |
