# Knowledge graph of the code

`docs/graph/` holds a knowledge graph of the project, built by
[graphify](https://github.com/safishamsi/graphify) from the code's syntax trees and the docs' headings and links
(no AI service involved): **439 nodes, 849 edges, 17 communities** across both apps' Swift sources,
the tests, the Python prototype, the README and these wiki pages.

- `graph.html`: open it in a browser to explore. Nodes are types, functions, files and doc sections; edges are
  calls, references, imports and links; colours are communities.
- `GRAPH_REPORT.md`: the most connected nodes, the communities and surprising links.
- `graph.json`: the raw graph, for `graphify query "..."`, `graphify path "A" "B"` or `graphify explain "X"`.

## What it shows

The most connected nodes are the spine of both apps, and they match the design:

| Node | Edges | Role |
|---|---|---|
| `LabSession` | 39 | Lab: count-in, click, takes, calibration (`LabSession.swift`) |
| `Meter` | 35 | Time signatures, groupings, which beats tap Strong (`Meter.swift`) |
| `Metronome` | 31 | Play state and the beat loop: the bridge between screen and timing (`Metronome.swift`) |
| `BeatClock` | 24 | The schedule: when the next beat is due (`BeatClock.swift`) |
| `OnsetDetector` | 20 | Lab: hears where each note starts (`OnsetDetector.swift`) |
| `RuntimeSession` | 19 | Keeps the app running with the wrist down (`RuntimeSession.swift`) |
| `MetronomeView` | 18 | The one screen: crown, tap, ring, accessibility (`MetronomeView.swift`) |
| `Feel` | 18 | Light or Strong, and its haptic (`Feel.swift`) |
| `TakeSummary` | 15 | Lab: the end-of-take verdict (`TimingAnalyzer.swift`) |
| `TimingAnalyzer` | 13 | Lab: matches notes to the grid (`TimingAnalyzer.swift`) |
| `.beatPlayed()` | 10 | Advance after a beat; skip after a stall (`BeatClock.swift`) |
| `TempoTests` | 10 | Tempo rules under test (`TempoTests.swift`) |

`Metronome` is the bridge between the screen and the timing core: the view never touches `BeatClock`, and
`BeatClock` never touches WatchKit. If a future change adds an edge from `MetronomeView` straight to
`BeatClock`, that boundary has been crossed.

The second boundary is between the apps. Tactus and Lab meet only in `Core/` (`BeatClock`, `Tempo`, `Meter`) and
`Shared/` (`RuntimeSession`). Today the only edges between `Tactus/` and `Lab/` are shared Apple framework imports
(SwiftUI, WatchKit, `os`, Observation), which graphify files under whichever app's file imported them first. Any
other edge between the two, a type or a call, means an experiment has leaked into the metronome.

## Rebuild it

```bash
pip install graphifyy
graphify update .                     # re-extracts code and docs; no API key needed
cp graphify-out/graph.html graphify-out/graph.json graphify-out/GRAPH_REPORT.md docs/graph/
```

`.graphifyignore` keeps `docs/graph/` itself and `.github/` out of the map.
