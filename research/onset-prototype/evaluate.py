"""Reproduces the validation table in docs/wiki/Lab.md. Run: python3 evaluate.py (needs numpy)."""
import numpy as np
from synth import practice_take, render
from detect import detect, match, analyze, summarize

CASES = [  # label, sample rate, room noise (dB re. peak), rush in runs (ms), bias elsewhere (ms), mic level
    ("Rushing runs, 48 kHz", 48000, -50, -30, 3, 0.05),
    ("Same, 16 kHz", 16000, -50, -30, 3, 0.05),
    ("Dragging runs", 48000, -45, 25, 3, 0.2),
    ("Steady player", 48000, -50, 0, 0, 0.05),
    ("Noisy room", 48000, -35, -30, 3, 0.05),
]

print("| Case | Notes heard | Precision | Timing spread | Runs measured (true) | Elsewhere measured (true) |")
print("|---|---|---|---|---|---|")
for label, sr, noise, rush, sparse, level in CASES:
    notes, truth, beats, dense, total = practice_take(seed=21, rush_dense_ms=rush, sparse_bias_ms=sparse)
    y = render(notes, total, sr=sr, seed=21, taptic_times=beats, taptic_level=0.3, noise_db=noise) * level
    found, _ = detect(y, sr)
    pairs = match(found, truth)
    err = np.array([found[j] - truth[i] for i, j in pairs]) * 1000
    bias = np.median(err)   # what calibration measures and removes
    s = summarize(analyze(found, beats[0], 60 / 100, 4, offset=bias / 1000), 4)
    spread = 1.4826 * np.median(np.abs(err - bias))
    print(f"| {label} | {len(pairs) / len(truth):.0%} | {len(pairs) / max(1, len(found)):.0%} | {spread:.1f} ms | "
          f"{s['dense_ms']:+.1f} ms ({rush:+d}) | {s['sparse_ms']:+.1f} ms ({sparse:+d}) |")
