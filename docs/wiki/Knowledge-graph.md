# Knowledge graph of the code

`docs/graph/` holds a knowledge graph of the project, built by
[graphify](https://github.com/safishamsi/graphify) from the code's syntax trees and the docs' headings and links
(no AI service involved): **174 nodes, 283 edges, 15 communities** across the Swift sources, the
tests, the README and these wiki pages.

- `graph.html`: open it in a browser to explore. Nodes are types, functions, files and doc sections; edges are
  calls, references, imports and links; colours are communities.
- `GRAPH_REPORT.md`: the most connected nodes, the communities and surprising links.
- `graph.json`: the raw graph, for `graphify query "..."`, `graphify path "A" "B"` or `graphify explain "X"`.

## What it shows

The most connected nodes are the spine of the app, and they match the design:

| Node | Edges | Role |
|---|---|---|
| `Metronome` | 26 | Play state and the beat loop: the bridge between screen and timing (`Metronome.swift`) |
| `BeatClock` | 22 | The schedule: when the next beat is due (`BeatClock.swift`) |
| `Feel` | 18 | Light or Strong, and its haptic (`Feel.swift`) |
| `RuntimeSession` | 17 | Keeps the app running with the wrist down (`RuntimeSession.swift`) |
| `MetronomeView` | 17 | The one screen: crown, tap, ring, accessibility (`MetronomeView.swift`) |
| `TempoTests` | 10 | Tempo rules under test (`TempoTests.swift`) |
| `.beatPlayed()` | 9 | Advance after a beat; skip after a stall (`BeatClock.swift`) |
| `BeatClockTests` | 9 | Clock rules under test (`BeatClockTests.swift`) |

`Metronome` is the bridge between the screen and the timing core: the view never touches `BeatClock`, and
`BeatClock` never touches WatchKit. If a future change adds an edge from `MetronomeView` straight to
`BeatClock`, that boundary has been crossed.

## Rebuild it

```bash
pip install graphifyy
graphify update .                     # re-extracts code and docs; no API key needed
cp graphify-out/graph.html graphify-out/graph.json graphify-out/GRAPH_REPORT.md docs/graph/
```

`.graphifyignore` keeps `docs/graph/` itself and `.github/` out of the map.
