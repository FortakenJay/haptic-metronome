# Running it

## On your watch

You need a Mac with **Xcode 16 or later**, an Apple Watch on **watchOS 26.6 or later**, and its paired iPhone. A free
Apple ID is enough.

```bash
git clone https://github.com/FortakenJay/haptic-metronome.git
cd haptic-metronome
open Tactus.xcodeproj
```

1. **Signing.** Select the **Tactus** target → **Signing & Capabilities** → **Team** → your Apple ID
   (*Personal Team*). Leave *Automatically manage signing* on.
2. **Bundle identifier.** If Xcode says `com.fortakenjay.tactus` is unavailable, change it to something only you
   would use, like `com.yourname.tactus`.
3. **Developer Mode.** Connect the iPhone to the Mac (cable, or the same Wi-Fi once paired). Then on the iPhone
   *and* on the watch: Settings → Privacy & Security → Developer Mode → on. Each device restarts.
4. **Run.** Scheme **Tactus**, destination your Apple Watch, press **Run** (⌘R). The first install to a watch
   can take a few minutes.

## Tactus Lab

Same steps with the **TactusLab** scheme. It installs as its own app, *Tactus Lab*, next to Tactus.

1. **Silent Mode on** (Control Center → bell). Otherwise the microphone hears the watch's own tap clicks.
2. **Calibrate once** (tuning fork, top left): stay quiet for 4 taps, then play one key on each of 8 taps. It
   says what it measured and saves it. Calibrate again if you change pianos or rooms.
3. **Pick the grid** (top right): ♩ ♪ 3 ♬ for the notes you're playing.
4. **Tap to start**, play after the 4-beat count-in, **tap to stop** for the summary.

The first take asks for microphone access. A free Apple ID allows 3 apps of yours on the watch at once; Tactus
and Lab are two of them.

## Every 7 days

A free Personal Team signs apps for 7 days. After that, Tactus won't open. Connect the iPhone and press **Run**
again. Nothing is lost: tempo and feel are saved on the watch.

## Tests

```bash
swift test
```

Runs the 34 tests in `Tests/` (beat clock, tempo, meters, onset detector, timing analysis) on the Mac. No watch or simulator
needed. GitHub Actions runs them, plus a full `xcodebuild` of the watch app, on every push
(`.github/workflows/build.yml`).

## The simulator

Choose any Apple Watch simulator as the destination and Run. The crown is your mouse's scroll wheel or trackpad
scroll. **The simulator has no Taptic Engine**, so you'll see the ring flash but feel nothing. Check the feel on a
real watch.

## Screenshots

`docs/img/` comes from the watch simulator on a GitHub macOS runner, not from a real watch:

- **Actions → screenshots → Run workflow** builds a Debug app, boots a 46 mm watch (`SHOTS_ONLY=medium`; unset it
  for 40 and 49 mm too), launches Tactus stopped and playing, takes 8 frames of each and force-pushes them to the
  `screenshots` branch. About 8 minutes.
- Playing needs a tap, which a simulator can't get from the command line, so Debug builds start on their own when
  launched with `-tactus.autostart YES`. Tempo and feel come from `-tempo.bpm 120` and `-tempo.feel strong`.
- Pick frames by hand: about one in three catches the ring lit on a beat.

Known rough edges: the third state (Strong at 168) comes up with default settings instead, autostart didn't fire
on the paired-iPhone run, and the red "no iPhone" icon stays even when an iPhone simulator is paired. The
images in `docs/img/` are from the run where stopped and playing both worked.

## When it goes wrong

| What you see | What it means | Fix |
|---|---|---|
| *Signing for "Tactus" requires a development team* | No Team picked | Step 1 above |
| *Failed to register bundle identifier* / *not available* | Someone else's app already has `com.fortakenjay.tactus` | Step 2: change the bundle identifier |
| *Your development team has reached the maximum number of registered devices* | A free team allows 3 devices per platform, for 7 days | Wait for one to expire, or use a paid account |
| The destination menu doesn't list the watch | Not paired, locked, or Developer Mode off | Unlock the watch, keep it on the charger near the iPhone, check step 3. In Xcode 27 there is no *Devices and Simulators* window; use *Manage Devices…* in the destination menu (Device Hub) |
| *A connection to this device could not be established* … *Timed out while attempting to establish tunnel* (CoreDeviceError 4000, RemotePairingError 1001) | Xcode reaches a watch over Wi-Fi, not a cable, and couldn't open that connection | Watch and Mac on the same Wi-Fi; VPN off on the Mac; turn the iPhone's Bluetooth off for a minute so the watch uses Wi-Fi. School networks (eduroam) usually block devices from reaching each other: use a home network |
| The app opened before but now won't | The 7-day signing ran out | Run again from Xcode |
| *Untrusted Developer* on first launch | iOS hasn't trusted your Apple ID yet | On the iPhone: Settings → General → VPN & Device Management → your Apple ID → Trust |
| Beats stop when you lower your wrist | The background session didn't start or was ended | Check `Support/Info.plist` still has `WKBackgroundModes` → `mindfulness`. Pressing the crown or opening another app also ends it, by design |
| Taps and screen stop together; console shows `Code=-536870187` once per beat | The background session ended and watchOS refused the haptics | Pull and Run again. To see why a session ended: Console.app → your watch → search `com.fortakenjay.tactus`; the `invalidated: reason N` line gives the reason (3 = left the app, 4 = suppressed by the system) |
| *Stopped after an hour* | The mindfulness session's 1-hour limit | Tap to start again |
| Beats blur together at fast tempos | The haptic takes about as long as the gap between beats | Switch to **Light** (hand button, top right) |
| `swift test` can't find XCTest | Command Line Tools without Xcode | `sudo xcode-select -s /Applications/Xcode.app` |
