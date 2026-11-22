# Graph Report - haptic-metronome  (2026-11-22)

## Corpus Check
- 47 files · ~23,719 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 9 file(s) not represented in the graph (top: (none) 3, .plist 2, .xcscheme 2)

## Summary
- 439 nodes · 849 edges · 17 communities (15 shown, 2 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 147 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `460e3092`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Metronome
- LabSession
- Meter
- Home.md
- TakeSummary
- LabView
- OnsetDetector
- TempoTests
- numpy
- LabSession.swift
- BeatClock
- Feel
- RuntimeSession
- .take
- XCTest
- screenshots.sh
- Package.swift

## God Nodes (most connected - your core abstractions)
1. `LabSession` - 39 edges
2. `Meter` - 35 edges
3. `Metronome` - 31 edges
4. `BeatClock` - 24 edges
5. `OnsetDetector` - 20 edges
6. `RuntimeSession` - 19 edges
7. `Feel` - 18 edges
8. `MetronomeView` - 18 edges
9. `TakeSummary` - 15 edges
10. `OnsetParameters` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Timing` --references--> `BeatClock`  [INFERRED]
  docs/wiki/Decisions.md → Core/BeatClock.swift
- `States and transitions` --references--> `BeatClock`  [INFERRED]
  docs/ARCHITECTURE.md → Core/BeatClock.swift
- `Starting` --references--> `BeatClock`  [INFERRED]
  docs/wiki/How-it-works.md → Core/BeatClock.swift
- `The clock` --references--> `BeatClock`  [INFERRED]
  docs/wiki/How-it-works.md → Core/BeatClock.swift
- `The pieces` --references--> `BeatClock`  [INFERRED]
  docs/wiki/How-it-works.md → Core/BeatClock.swift

## Import Cycles
- None detected.

## Communities (17 total, 2 thin omitted)

### Community 0 - "Metronome"
Cohesion: 0.06
Nodes (24): State, Decisions, by component, Docs and graph, Haptics, Interface, Meters, Project and platform, Running with the wrist down (+16 more)

### Community 1 - "LabSession"
Cohesion: 0.07
Nodes (21): Duration, .inSeconds, LabSession, .isRunning, Key, Phase, calibrationPlay, calibrationQuiet (+13 more)

### Community 2 - "Meter"
Cohesion: 0.08
Nodes (15): Meter, Accent, downbeat, group, plain, .countsEighths, .groupingLabel, .groupStarts (+7 more)

### Community 3 - "Home.md"
Cohesion: 0.07
Nodes (28): Tactus wiki, Knowledge graph of the code, Rebuild it, A take, Calibration, Clocks, Code, How it hears a note (+20 more)

### Community 4 - "TakeSummary"
Cohesion: 0.13
Nodes (11): What it shows, .body, Calibration, NoteTiming, Stats, TakeSummary, .headline, Stretch (+3 more)

### Community 5 - "LabView"
Cohesion: 0.07
Nodes (15): Interface, Meters on the screen, Small things that are deliberate, What wasn't checked, TactusLabApp, .body, LabView, .body (+7 more)

### Community 6 - "OnsetDetector"
Cohesion: 0.14
Nodes (4): Accelerate, OnsetDetector, OnsetParameters, OnsetDetectorTests

### Community 7 - "TempoTests"
Cohesion: 0.12
Nodes (11): Tempo, Checked by tests (`Tests/TactusCoreTests`), Haptics, How it works, The beat loop, The clock, The pieces, With the wrist down (+3 more)

### Community 8 - "numpy"
Cohesion: 0.17
Nodes (11): analyze(), detect(), match(), onset_time(), Params, pick_peaks(), spectral_flux(), summarize() (+3 more)

### Community 9 - "LabSession.swift"
Cohesion: 0.12
Nodes (12): AVFAudio, Foundation, AudioInput, Failure, .errorDescription, noMicrophone, hostNow(), Observation (+4 more)

### Community 10 - "BeatClock"
Cohesion: 0.19
Nodes (8): BeatClock, Concurrency, Invariants, Layers, Open, States and transitions, Tactus: Architecture, BeatClockTests

### Community 11 - "Feel"
Cohesion: 0.12
Nodes (15): Feel, light, .name, .next, strong, .tap, Tap, light (+7 more)

### Community 12 - "RuntimeSession"
Cohesion: 0.15
Nodes (5): RuntimeSession, End, expired, interrupted, .isActive

### Community 13 - ".take"
Cohesion: 0.35
Nodes (3): SplitMix, SyntheticPiano, SyntheticTake

### Community 14 - "XCTest"
Cohesion: 0.36
Nodes (3): LabCore, TactusCore, XCTest

## Knowledge Gaps
- **46 isolated node(s):** `light`, `strong`, `light`, `strong`, `.next` (+41 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 145 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `What it shows` connect `TakeSummary` to `Metronome`, `LabSession`, `Meter`, `Home.md`, `OnsetDetector`, `TempoTests`, `BeatClock`, `Feel`, `RuntimeSession`?**
  _High betweenness centrality (0.257) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `LabSession` (e.g. with `Tactus Lab` and `What it shows`) actually correct?**
  _`LabSession` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `light`, `strong`, `light` to the rest of the system?**
  _46 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Metronome` be split into smaller, more focused modules?**
  _Cohesion score 0.058823529411764705 - nodes in this community are weakly interconnected._
- **Why does `LabSession` connect `LabSession` to `Metronome`, `TakeSummary`, `LabView`, `LabSession.swift`, `BeatClock`, `RuntimeSession`?**
  _High betweenness centrality (0.231) - this node is a cross-community bridge._
- **Are the 11 inferred relationships involving `Meter` (e.g. with `State` and `The pieces`) actually correct?**
  _`Meter` has 11 INFERRED edges - model-reasoned connections that need verification._
- **Should `LabSession` be split into smaller, more focused modules?**
  _Cohesion score 0.06767676767676768 - nodes in this community are weakly interconnected._