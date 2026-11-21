# Graph Report - haptic-metronome  (2026-11-21)

## Corpus Check
- 24 files · ~10,007 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: (none) 3, .plist 1, .pbxproj 1)

## Summary
- 179 nodes · 300 edges · 12 communities (9 shown, 3 thin omitted)
- Extraction: 77% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 70 edges (avg confidence: 0.91)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e58c26b2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Metronome
- MetronomeView
- Home.md
- TempoTests
- RuntimeSession
- BeatClock
- Feel
- Metronome.swift
- Decisions, by component
- BeatClockTests.swift
- screenshots.sh
- Package.swift

## God Nodes (most connected - your core abstractions)
1. `Metronome` - 29 edges
2. `BeatClock` - 22 edges
3. `RuntimeSession` - 19 edges
4. `Feel` - 18 edges
5. `MetronomeView` - 17 edges
6. `TempoTests` - 10 edges
7. `BeatClockTests` - 9 edges
8. `TactusApp` - 8 edges
9. `Tactus` - 8 edges
10. `What it shows` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Timing` --references--> `BeatClock`  [INFERRED]
  docs/wiki/Decisions.md → Tactus/Core/BeatClock.swift
- `Running with the wrist down` --references--> `TactusApp`  [INFERRED]
  docs/wiki/Decisions.md → Tactus/TactusApp.swift
- `States and transitions` --references--> `BeatClock`  [INFERRED]
  docs/ARCHITECTURE.md → Tactus/Core/BeatClock.swift
- `Starting` --references--> `BeatClock`  [INFERRED]
  docs/wiki/How-it-works.md → Tactus/Core/BeatClock.swift
- `The clock` --references--> `BeatClock`  [INFERRED]
  docs/wiki/How-it-works.md → Tactus/Core/BeatClock.swift

## Import Cycles
- None detected.

## Communities (12 total, 3 thin omitted)

### Community 0 - "Metronome"
Cohesion: 0.12
Nodes (11): Concurrency, Layers, Open, State, States and transitions, Tactus: Architecture, Starting, Metronome (+3 more)

### Community 1 - "MetronomeView"
Cohesion: 0.09
Nodes (14): With the wrist down, Interface, Rules the screen follows, Small things that are deliberate, What wasn't checked, SwiftUI, BeatPulse, MetronomeView (+6 more)

### Community 2 - "Home.md"
Cohesion: 0.12
Nodes (15): Tactus wiki, Every 7 days, On your watch, Running it, Screenshots, Tests, The simulator, When it goes wrong (+7 more)

### Community 3 - "TempoTests"
Cohesion: 0.11
Nodes (10): Checked by tests (`Tests/TactusCoreTests`), Haptics, How it works, The beat loop, The clock, The pieces, Inside, Tempo (+2 more)

### Community 4 - "RuntimeSession"
Cohesion: 0.15
Nodes (5): RuntimeSession, End, expired, interrupted, .isActive

### Community 5 - "BeatClock"
Cohesion: 0.26
Nodes (3): Invariants, BeatClock, BeatClockTests

### Community 6 - "Feel"
Cohesion: 0.14
Nodes (9): Knowledge graph of the code, Rebuild it, What it shows, Feel, light, .name, .next, strong (+1 more)

### Community 7 - "Metronome.swift"
Cohesion: 0.22
Nodes (6): Foundation, Observation, os, Duration, .inSeconds, WatchKit

### Community 8 - "Decisions, by component"
Cohesion: 0.29
Nodes (7): Decisions, by component, Docs and graph, Haptics, Interface, Project and platform, Running with the wrist down, Timing

## Knowledge Gaps
- **14 isolated node(s):** `PackageDescription`, `light`, `strong`, `.next`, `.name` (+9 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 68 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Metronome` connect `Metronome` to `MetronomeView`, `TempoTests`, `BeatClock`, `Feel`, `Metronome.swift`?**
  _High betweenness centrality (0.279) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `Metronome` (e.g. with `Concurrency` and `Invariants`) actually correct?**
  _`Metronome` has 7 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `light`, `strong` to the rest of the system?**
  _14 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Metronome` be split into smaller, more focused modules?**
  _Cohesion score 0.11612903225806452 - nodes in this community are weakly interconnected._
- **Why does `Inside` connect `TempoTests` to `Metronome`, `MetronomeView`, `Home.md`, `RuntimeSession`, `BeatClock`, `Feel`?**
  _High betweenness centrality (0.210) - this node is a cross-community bridge._
- **Are the 15 inferred relationships involving `BeatClock` (e.g. with `States and transitions` and `Timing`) actually correct?**
  _`BeatClock` has 15 INFERRED edges - model-reasoned connections that need verification._
- **Should `MetronomeView` be split into smaller, more focused modules?**
  _Cohesion score 0.08615384615384615 - nodes in this community are weakly interconnected._