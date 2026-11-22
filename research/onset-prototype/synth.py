"""Synthetic piano-practice audio with known onset times, for tuning the onset detector.

A take is a list of notes (time, pitch, velocity). The audio is piano-like: harmonic partials with
per-partial decay, a short hammer-noise burst, a little reverb, room noise, and optionally the watch's
own Taptic buzz at every beat (a ~180 Hz burst), which the detector must ignore.
"""
import numpy as np


def piano_note(sr, freq, vel, dur, rng):
    n = int(dur * sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    B = 0.0004  # inharmonicity
    k = 1
    while True:
        fk = k * freq * np.sqrt(1 + B * k * k)
        if fk > min(9000, sr / 2 - 500) or k > 40:
            break
        amp = vel / (k ** 1.1)
        tau = 1.2 / (1 + 0.35 * k) * (220 / max(freq, 60)) ** 0.3
        out += amp * np.exp(-t / tau) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 2 * np.pi))
        k += 1
    attack = int(0.002 * sr)
    out[:attack] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(attack) / attack)
    hammer = int(0.006 * sr)
    noise = rng.standard_normal(hammer) * np.exp(-np.arange(hammer) / (0.0015 * sr))
    out[:hammer] += 0.15 * vel * noise
    return out


def render(notes, total, sr=48000, seed=1, taptic_times=(), taptic_level=0.05, noise_db=-50, reverb=0.12):
    rng = np.random.default_rng(seed)
    y = np.zeros(int(total * sr) + sr)
    for (t0, midi, vel) in notes:
        f = 440 * 2 ** ((midi - 69) / 12)
        x = piano_note(sr, f, vel, min(2.5, total - t0 + 0.5), rng)
        i = int(round(t0 * sr))
        y[i:i + len(x)] += x[: len(y) - i]
    if reverb:
        ir_n = int(0.7 * sr)
        ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / (0.15 * sr))
        ir[: int(0.01 * sr)] = 0
        wet = np.convolve(y, ir)[: len(y)]
        y = y + reverb * wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(y))
    for tt in taptic_times:  # the watch's own haptic, felt through the case
        i = int(round(tt * sr))
        m = int(0.04 * sr)
        tb = np.arange(m) / sr
        burst = taptic_level * np.sin(2 * np.pi * 180 * tb) * np.sin(np.pi * tb / 0.04)
        y[i:i + m] += burst[: len(y) - i]
    y /= np.max(np.abs(y)) + 1e-9
    y += 10 ** (noise_db / 20) * rng.standard_normal(len(y))
    return y.astype(np.float32)


def practice_take(bpm=100, bars=16, seed=3, rush_dense_ms=-30.0, sparse_bias_ms=3.0, jitter_ms=8.0):
    """Alternates 2 bars of sparse playing (quarters, chords) with 2 bars of 16th-note runs.
    Returns (notes, true_onsets, beat_times, dense_flags, total_seconds). Times are seconds; beat 0 at 1.0 s."""
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    t0 = 1.0
    notes, onsets, dense = [], [], []
    beats = [t0 + i * beat for i in range(bars * 4 + 1)]
    for bar in range(bars):
        is_dense = (bar // 2) % 2 == 1
        for b in range(4):
            grid0 = t0 + (bar * 4 + b) * beat
            subs = [0, 0.25, 0.5, 0.75] if is_dense else [0]
            for s in subs:
                bias = rush_dense_ms if is_dense else sparse_bias_ms
                dev = (bias + rng.normal(0, jitter_ms)) / 1000.0
                t = grid0 + s * beat + dev
                if is_dense:
                    midi = 60 + int(rng.integers(0, 24))
                    notes.append((t, midi, rng.uniform(0.35, 0.8)))
                else:
                    root = 48 + int(rng.integers(0, 12))
                    vel = rng.uniform(0.4, 1.0)
                    for k, iv in enumerate((0, 4, 7, 12)):  # a chord, slightly rolled (<8 ms)
                        notes.append((t + k * rng.uniform(0, 0.002), root + iv, vel * rng.uniform(0.7, 1.0)))
                onsets.append(t)
                dense.append(is_dense)
    total = t0 + bars * 4 * beat + 1.5
    return notes, np.array(onsets), np.array(beats), np.array(dense), total
