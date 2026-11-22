import Foundation

/// Deterministic piano-like test audio with known onset times, a Swift twin of the Python prototype's generator
/// (docs/wiki/Lab.md): harmonic partials with per-partial decay, a hammer-noise burst, room noise, and optionally
/// the watch's own Taptic buzz (~180 Hz) at every beat.
struct SyntheticTake {
    let sampleRate: Double
    let samples: [Float]
    /// True onset times in seconds, one per played event (a chord counts once).
    let onsets: [Double]
    /// Beat times in seconds.
    let beats: [Double]
    /// For each onset, whether it was in a dense run.
    let dense: [Bool]
}

/// Tiny reproducible random generator (SplitMix64) so tests don't depend on the platform's RNG.
struct SplitMix {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func uniform(_ a: Double = 0, _ b: Double = 1) -> Double {
        a + (b - a) * Double(next() >> 11) / Double(1 << 53)
    }
    mutating func normal() -> Double {
        let u1 = max(uniform(), 1e-12), u2 = uniform()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

enum SyntheticPiano {
    /// Alternates two sparse bars (chords on the beat) with two bars of sixteenth-note runs.
    /// `rushInRuns` and `sparseBias` are in seconds (negative = early); `jitter` is the per-note spread.
    static func take(
        bpm: Double = 100, bars: Int = 8, sampleRate: Double = 16_000, seed: UInt64 = 3,
        rushInRuns: Double = -0.030, sparseBias: Double = 0.003, jitter: Double = 0.006,
        noiseLevel: Float = 0.003, taptic: Bool = true, gain: Float = 1
    ) -> SyntheticTake {
        var rng = SplitMix(state: seed)
        let beat = 60 / bpm
        let start = 1.0
        let total = start + Double(bars * 4) * beat + 1.2
        var y = [Float](repeating: 0, count: Int(total * sampleRate))
        var onsets: [Double] = [], dense: [Bool] = []
        let beats = (0...(bars * 4)).map { start + Double($0) * beat }

        for bar in 0..<bars {
            let isDense = (bar / 2) % 2 == 1
            for b in 0..<4 {
                let grid = start + Double(bar * 4 + b) * beat
                for s in (isDense ? [0, 0.25, 0.5, 0.75] : [0.0]) {
                    let bias = isDense ? rushInRuns : sparseBias
                    let t = grid + s * beat + bias + jitter * rng.normal()
                    if isDense {
                        addNote(&y, at: t, midi: 60 + Int(rng.uniform(0, 24)), velocity: Float(rng.uniform(0.35, 0.8)), sr: sampleRate, rng: &rng)
                    } else {
                        let root = 48 + Int(rng.uniform(0, 12)), velocity = Float(rng.uniform(0.4, 1))
                        for (k, interval) in [0, 7].enumerated() {
                            addNote(&y, at: t + Double(k) * rng.uniform(0, 0.002), midi: root + interval, velocity: velocity, sr: sampleRate, rng: &rng)
                        }
                    }
                    onsets.append(t)
                    dense.append(isDense)
                }
            }
        }
        if taptic {
            for t in beats { addTaptic(&y, at: t, sr: sampleRate) }
        }
        let peak = y.map(abs).max() ?? 1
        for i in y.indices { y[i] = gain * (y[i] / peak + noiseLevel * Float(rng.normal())) }
        return SyntheticTake(sampleRate: sampleRate, samples: y, onsets: onsets, beats: beats, dense: dense)
    }

    /// Only room noise and the Taptic buzz, no playing.
    static func silence(seconds: Double = 8, sampleRate: Double = 16_000, beatEvery: Double = 0.6, gain: Float = 0.05) -> [Float] {
        var rng = SplitMix(state: 99)
        var y = [Float](repeating: 0, count: Int(seconds * sampleRate))
        var t = 0.5
        while t < seconds - 0.1 { addTaptic(&y, at: t, sr: sampleRate); t += beatEvery }
        return y.map { gain * ($0 + 0.003 * Float(rng.normal())) }
    }

    private static func addNote(_ y: inout [Float], at t: Double, midi: Int, velocity: Float, sr: Double, rng: inout SplitMix) {
        let f0 = 440 * pow(2, Double(midi - 69) / 12)
        let start = Int((t * sr).rounded())
        let length = Int(0.7 * sr)
        let limit = min(sr / 2 - 300, 6_000)
        var partials: [(w: Double, amp: Float, decay: Double, phase: Double)] = []
        var k = 1
        while k <= 14 {
            let f = Double(k) * f0 * (1 + 0.0004 * Double(k * k)).squareRoot()
            if f > limit { break }
            let tau = 1.2 / (1 + 0.35 * Double(k)) * pow(220 / max(f0, 60), 0.3)
            partials.append((2 * .pi * f / sr, velocity / Float(pow(Double(k), 1.1)), exp(-1 / (tau * sr)), rng.uniform(0, 2 * .pi)))
            k += 1
        }
        let attack = Int(0.002 * sr), hammer = Int(0.006 * sr)
        for i in 0..<length where start + i < y.count && start + i >= 0 {
            var v: Float = 0
            for p in partials {
                v += p.amp * Float(pow(p.decay, Double(i)) * sin(p.w * Double(i) + p.phase))
            }
            if i < attack { v *= Float(0.5 - 0.5 * cos(.pi * Double(i) / Double(attack))) }
            if i < hammer { v += 0.15 * velocity * Float(rng.normal() * exp(-Double(i) / (0.0015 * sr))) }
            y[start + i] += v
        }
    }

    private static func addTaptic(_ y: inout [Float], at t: Double, sr: Double) {
        let start = Int((t * sr).rounded()), length = Int(0.04 * sr)
        for i in 0..<length where start + i < y.count {
            let x = Double(i) / sr
            y[start + i] += Float(0.3 * sin(2 * .pi * 180 * x) * sin(.pi * x / 0.04))
        }
    }
}
