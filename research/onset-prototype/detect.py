"""Reference onset detector and timing analysis. LabCore/OnsetDetector.swift is a port of this.

Onsets: level-normalised log spectral flux over bins >= fmin Hz (ignores the Taptic buzz and room rumble),
adaptive-threshold peak picking, and a parabolic fit through the flux peak for sub-frame timing.
"""
import numpy as np


class Params:
    def __init__(self, sr):
        self.sr = sr
        self.n = 1 << int(np.ceil(np.log2(0.021 * sr)))   # ~21 ms window: 1024 at 48 kHz, 512 at 16 kHz
        self.hop = self.n // 4                              # ~5.3 ms
        self.fmin = 1000.0
        self.gamma = 10.0
        self.ref_decay = 0.9995                             # per frame: the level reference halves in ~7 s
        self.ref_floor = 1e-3
        self.pre_max, self.post_max = 3, 2                  # frames; post_max is the detector's lookahead
        self.avg_window = 20                                # frames (~107 ms) for the adaptive mean
        self.delta = 0.4                                    # threshold above mean, in units of the long-term mean
        self.long_window = 400                              # frames (~2 s) for the long-term mean
        self.min_gap = 0.030                                # seconds between onsets


def spectral_flux(y, p):
    win = np.hanning(p.n + 1)[:-1].astype(np.float32)
    frames = 1 + (len(y) - p.n) // p.hop
    lo = int(np.ceil(p.fmin * p.n / p.sr))
    prev = None
    ref = p.ref_floor
    flux = np.zeros(frames, dtype=np.float32)
    for t in range(frames):
        seg = y[t * p.hop: t * p.hop + p.n] * win
        mag = np.abs(np.fft.rfft(seg))[lo:]
        # level normalisation: divide by a slowly decaying peak of the loudest bin, so the compression
        # behaves the same whether the mic hears the piano at 0.005 or 1.0 full scale
        ref = max(ref * p.ref_decay, float(np.max(mag)), p.ref_floor)
        s = np.log1p(p.gamma * mag / ref)
        if prev is not None:
            d = s - prev
            flux[t] = np.sum(d[d > 0])
        prev = s
    return flux


def pick_peaks(flux, p):
    out = []
    last = -1e9
    long_sum = 0.0
    for t in range(len(flux)):
        long_sum += flux[t]
        if t - p.long_window >= 0:
            long_sum -= flux[t - p.long_window]
        long_mean = long_sum / min(t + 1, p.long_window)
        if t < p.pre_max or t + p.post_max >= len(flux):
            continue
        lo, hi = t - p.pre_max, t + p.post_max + 1
        if flux[t] < np.max(flux[lo:hi]):
            continue
        a = max(0, t - p.avg_window)
        local_mean = np.mean(flux[a:hi])
        if flux[t] < local_mean + p.delta * long_mean:
            continue
        time = t * p.hop / p.sr
        if time - last < p.min_gap:
            continue
        out.append(t)
        last = time
    return out


def onset_time(flux, t, p):
    """Frame centre plus a parabolic fit through the flux peak and its neighbours (sub-hop precision)."""
    a, b, c = (flux[t - 1], flux[t], flux[t + 1]) if 0 < t < len(flux) - 1 else (0, flux[t], 0)
    denom = a - 2 * b + c
    frac = 0.5 * (a - c) / denom if denom != 0 else 0.0
    frac = max(-0.5, min(0.5, frac))
    return ((t + frac) * p.hop + p.n / 2) / p.sr


def detect(y, sr, params=None):
    p = params or Params(sr)
    flux = spectral_flux(y, p)
    frames = pick_peaks(flux, p)
    return np.array([onset_time(flux, t, p) for t in frames]), flux


def match(detected, truth, tol=0.05):
    used = set()
    pairs = []
    for i, t in enumerate(truth):
        j = int(np.argmin(np.abs(detected - t))) if len(detected) else -1
        if j >= 0 and abs(detected[j] - t) <= tol and j not in used:
            used.add(j)
            pairs.append((i, j))
    return pairs


def analyze(onsets, beat0, interval, subdivision, offset=0.0, accept=0.35):
    """Deviation of each onset from the nearest subdivision of the beat grid (negative = early = rushing)."""
    sub = interval / subdivision
    rows = []
    for t in onsets:
        tc = t - offset
        k = round((tc - beat0) / sub)
        dev = tc - (beat0 + k * sub)
        if abs(dev) <= accept * sub and k >= 0:
            rows.append((t, k, dev))
    return rows


def summarize(rows, subdivision, dense_at=3):
    """Median deviations overall, in dense beats (>= dense_at notes) and in sparse beats."""
    if not rows:
        return {}
    beats = {}
    for (_, k, dev) in rows:
        beats.setdefault(k // subdivision, []).append(dev)
    dense = [d for b in beats.values() if len(b) >= dense_at for d in b]
    sparse = [d for b in beats.values() if len(b) < dense_at for d in b]
    devs = np.array([r[2] for r in rows])
    return {
        "n": len(rows),
        "median_ms": 1000 * float(np.median(devs)),
        "spread_ms": 1000 * float(np.median(np.abs(devs - np.median(devs)))) * 1.4826,
        "dense_ms": 1000 * float(np.median(dense)) if dense else None,
        "sparse_ms": 1000 * float(np.median(sparse)) if sparse else None,
    }
