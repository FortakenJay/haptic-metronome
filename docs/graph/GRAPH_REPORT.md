# Graph Report - haptic-metronome  (2026-11-21)

## Corpus Check
- 24 files · ~9,193 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: (none) 3, .plist 1, .pbxproj 1)

## Summary
- 174 nodes · 283 edges · 15 communities (11 shown, 4 thin omitted)
- Extraction: 78% EXTRACTED · 22% INFERRED · 0% AMBIGUOUS · INFERRED: 61 edges (avg confidence: 0.91)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1712efee`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- MetronomeView
- Metronome
- TempoTests
- BeatClock
- RuntimeSession
- Feel
- Home.md
- Metronome.swift
- Decisions, by component
- How it works
- Running it
- Tactus
- BeatClockTests.swift
- screenshots.sh
- Package.swift

## God Nodes (most connected - your core abstractions)
1. `Metronome` - 26 edges
2. `BeatClock` - 22 edges
3. `Feel` - 18 edges
4. `MetronomeView` - 17 edges
5. `RuntimeSession` - 17 edges
6. `TempoTests` - 10 edges
7. `BeatClockTests` - 9 edges
8. `Tactus` - 8 edges
9. `What it shows` - 8 edges
10. `Tempo` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Timing` --references--> `BeatClock`  [INFERRED]
  docs/wiki/Decisions.md → Tactus/Core/BeatClock.swift
- `With the wrist down` --references--> `RuntimeSession`  [INFERRED]
  docs/wiki/How-it-works.md → Tactus/RuntimeSession.swift
- `Checked by tests (`Tests/TactusCoreTests`)` --references--> `TempoTests`  [INFERRED]
  docs/wiki/How-it-works.md → Tests/TactusCoreTests/TempoTests.swift
- `States and transitions` --references--> `BeatClock`  [INFERRED]
  docs/ARCHITECTURE.md → Tactus/Core/BeatClock.swift
- `Starting` --references--> `BeatClock`  [INFERRED]
  docs/wiki/How-it-works.md → Tactus/Core/BeatClock.swift

## Import Cycles
- None detected.

## Communities (15 total, 4 thin omitted)

### Community 0 - "MetronomeView"
Cohesion: 0.08
Nodes (15): Interface, Rules the screen follows, Small things that are deliberate, What wasn't checked, SwiftUI, BeatPulse, MetronomeView, .accessibilityValue (+7 more)

### Community 1 - "Metronome"
Cohesion: 0.12
Nodes (10): Concurrency, Layers, Open, State, States and transitions, Tactus: Architecture, Starting, Metronome (+2 more)

### Community 2 - "TempoTests"
Cohesion: 0.17
Nodes (3): Inside, Tempo, TempoTests

### Community 3 - "BeatClock"
Cohesion: 0.26
Nodes (3): Invariants, BeatClock, BeatClockTests

### Community 4 - "RuntimeSession"
Cohesion: 0.17
Nodes (4): RuntimeSession, End, expired, interrupted

### Community 5 - "Feel"
Cohesion: 0.14
Nodes (9): Knowledge graph of the code, Rebuild it, What it shows, Feel, light, .name, .next, strong (+1 more)

### Community 7 - "Metronome.swift"
Cohesion: 0.22
Nodes (5): Foundation, Observation, Duration, .inSeconds, WatchKit

### Community 8 - "Decisions, by component"
Cohesion: 0.29
Nodes (7): Decisions, by component, Docs and graph, Haptics, Interface, Project and platform, Running with the wrist down, Timing

### Community 9 - "How it works"
Cohesion: 0.29
Nodes (7): Checked by tests (`Tests/TactusCoreTests`), Haptics, How it works, The beat loop, The clock, The pieces, With the wrist down

### Community 10 - "Running it"
Cohesion: 0.29
Nodes (7): Every 7 days, On your watch, Running it, Screenshots, Tests, The simulator, When it goes wrong

### Community 11 - "Tactus"
Cohesion: 0.29
Nodes (7): A click you don't have to hear, How this was built, Run it on your own watch (free), Tactus, The timing, What it does, What it doesn't do yet

## Knowledge Gaps
- **13 isolated node(s):** `PackageDescription`, `light`, `strong`, `.next`, `.name` (+8 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 67 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Metronome` connect `Metronome` to `MetronomeView`, `TempoTests`, `BeatClock`, `Feel`, `Metronome.swift`?**
  _High betweenness centrality (0.256) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `Metronome` (e.g. with `Concurrency` and `Invariants`) actually correct?**
  _`Metronome` has 7 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `light`, `strong` to the rest of the system?**
  _13 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `MetronomeView` be split into smaller, more focused modules?**
  _Cohesion score 0.08465608465608465 - nodes in this community are weakly interconnected._
- **Why does `MetronomeView` connect `MetronomeView` to `Metronome`, `TempoTests`, `Feel`?**
  _High betweenness centrality (0.229) - this node is a cross-community bridge._
- **Are the 15 inferred relationships involving `BeatClock` (e.g. with `States and transitions` and `Timing`) actually correct?**
  _`BeatClock` has 15 INFERRED edges - model-reasoned connections that need verification._
- **Should `Metronome` be split into smaller, more focused modules?**
  _Cohesion score 0.11965811965811966 - nodes in this community are weakly interconnected._