import Accelerate

/// Settings for `OnsetDetector`. The defaults were tuned on synthetic piano takes (see docs/wiki/Lab.md):
/// 99 % of notes found at normal room noise, timing spread about 1 ms.
public struct OnsetParameters: Sendable, Equatable {
    public var sampleRate: Double
    /// FFT size: the power of two nearest above 21 ms (1024 at 48 kHz, 512 at 16 kHz).
    public var fftSize: Int
    /// Frames start this many samples apart (a quarter of the FFT, about 5.3 ms).
    public var hop: Int
    /// Only bins at or above this frequency count. A hammer strike is broadband; the watch's own Taptic buzz
    /// (about 180 Hz) and room rumble are not, so they never become onsets.
    public var minFrequency: Double = 1000
    /// Log compression strength: `log(1 + γ · |X| / level)`.
    public var compression: Float = 10
    /// The level reference decays by this factor per frame (halves in about 7 s at 5.3 ms frames).
    public var levelDecay: Float = 0.9995
    public var levelFloor: Float = 1e-3
    /// A peak must be the largest flux from `preMax` frames before to `postMax` frames after. `postMax` is the
    /// detector's lookahead, so an onset is reported about `postMax` frames (11 ms) after it happens.
    public var preMax = 3
    public var postMax = 2
    /// Frames before the peak in the local mean.
    public var averageWindow = 20
    /// Frames in the long-term mean (about 2 s).
    public var longWindow = 400
    /// A peak must exceed the local mean by this many long-term means.
    public var delta: Float = 0.4
    /// Seconds between two onsets: a rolled chord counts once.
    public var minGap: Double = 0.030
    /// Frames to listen before reporting anything, so the threshold has some history (about 100 ms).
    public var warmUp = 20

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        var n = 1
        while Double(n) < 0.021 * sampleRate { n <<= 1 }
        fftSize = n
        hop = n / 4
    }
}

/// Finds note onsets in a stream of microphone samples: log-compressed spectral flux above 1 kHz, a threshold
/// that adapts to the room, and a parabolic fit through the peak for sub-frame timing.
///
/// Feed it buffers in order with `process(_:startTime:)`; it returns the onsets it has confirmed, as times on the
/// same clock as `startTime`. Not thread-safe: call it from one thread (the audio tap's).
public final class OnsetDetector {
    public let parameters: OnsetParameters

    private let window: [Float]
    private let firstBin: Int
    private let bins: Int
    private let log2n: vDSP_Length
    private let fft: FFTSetup

    private var pending: [Float] = []
    private var pendingStart: Double?
    private var frameCount = 0
    private var history: [Float] = []        // recent flux; last element is the newest frame
    private var historyTimes: [Double] = []  // start time of each frame in `history`
    private var previous: [Float]?
    private var level: Float
    private var lastOnsetFrameTime = -Double.infinity

    private var real: [Float]
    private var imag: [Float]
    private var windowed: [Float]
    private var magnitudes: [Float]

    public init(parameters: OnsetParameters) {
        self.parameters = parameters
        let n = parameters.fftSize
        precondition(n >= 64 && n & (n - 1) == 0, "fftSize must be a power of two")
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: n, isHalfWindow: false)
        firstBin = max(1, Int((parameters.minFrequency * Double(n) / parameters.sampleRate).rounded(.up)))
        bins = max(1, n / 2 - firstBin)
        log2n = vDSP_Length(n.trailingZeroBitCount)
        fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        level = parameters.levelFloor
        real = [Float](repeating: 0, count: n / 2)
        imag = [Float](repeating: 0, count: n / 2)
        windowed = [Float](repeating: 0, count: n)
        magnitudes = [Float](repeating: 0, count: n / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(fft)
    }

    /// Adds samples whose first sample was captured at `startTime` (seconds). A gap or overlap of more than a
    /// couple of samples since the last buffer restarts framing, so timestamps never drift.
    public func process(_ samples: [Float], startTime: Double) -> [Double] {
        let sr = parameters.sampleRate
        if let start = pendingStart, !pending.isEmpty {
            let expected = start + Double(pending.count) / sr
            if abs(startTime - expected) > 2 / sr {
                pending.removeAll(keepingCapacity: true)
                pendingStart = startTime
            }
        } else {
            pendingStart = startTime
        }
        pending.append(contentsOf: samples)

        var onsets: [Double] = []
        let n = parameters.fftSize, hop = parameters.hop
        var offset = 0
        while pending.count - offset >= n {
            let frameStart = pendingStart! + Double(offset) / sr
            let flux = spectralFlux(at: offset)
            push(flux, time: frameStart)
            if let onset = confirmCandidate() { onsets.append(onset) }
            offset += hop
        }
        if offset > 0 {
            pending.removeFirst(offset)
            pendingStart! += Double(offset) / sr
        }
        return onsets
    }

    /// Forgets everything, for a new take.
    public func reset() {
        pending.removeAll()
        pendingStart = nil
        frameCount = 0
        history.removeAll()
        historyTimes.removeAll()
        previous = nil
        level = parameters.levelFloor
        lastOnsetFrameTime = -.infinity
    }

    // MARK: - Spectral flux

    private func spectralFlux(at offset: Int) -> Float {
        let n = parameters.fftSize
        pending.withUnsafeBufferPointer { src in
            vDSP.multiply(UnsafeBufferPointer(rebasing: src[offset..<(offset + n)]), window, result: &windowed)
        }
        real.withUnsafeMutableBufferPointer { re in
            imag.withUnsafeMutableBufferPointer { im in
                var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                windowed.withUnsafeBufferPointer { w in
                    w.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }
                vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }
        // Bins at and above minFrequency (index 0 packs DC and Nyquist and is never used).
        let raw = magnitudes[firstBin..<(firstBin + bins)]
        let peak = vDSP.maximum(raw)
        level = max(level * parameters.levelDecay, peak, parameters.levelFloor)
        // Level-normalised log compression, log(1 + γ·|X|/level): the same curve however loud the mic hears the piano.
        var band = vDSP.multiply(parameters.compression / level, raw)
        var count = Int32(band.count)
        band.withUnsafeMutableBufferPointer { b in vvlog1pf(b.baseAddress!, b.baseAddress!, &count) }

        defer { previous = band }
        guard let previous else { return 0 }
        var flux: Float = 0
        for i in 0..<band.count {
            let d = band[i] - previous[i]
            if d > 0 { flux += d }
        }
        return flux
    }

    // MARK: - Peak picking

    private func push(_ flux: Float, time: Double) {
        history.append(flux)
        historyTimes.append(time)
        frameCount += 1
        let keep = parameters.longWindow + parameters.postMax + 2
        if history.count > keep + 64 {
            history.removeFirst(history.count - keep)
            historyTimes.removeFirst(historyTimes.count - keep)
        }
    }

    /// Looks at the frame `postMax` frames ago, now that its lookahead exists.
    private func confirmCandidate() -> Double? {
        let p = parameters
        let c = history.count - 1 - p.postMax
        let absolute = frameCount - 1 - p.postMax
        guard c >= 1, absolute >= max(p.preMax, p.warmUp), c - p.preMax >= 0 else { return nil }

        let value = history[c]
        for i in (c - p.preMax)...(c + p.postMax) where history[i] > value { return nil }

        let localStart = max(0, c - p.averageWindow)
        let local = history[localStart...(c + p.postMax)]
        let localMean = local.reduce(0, +) / Float(local.count)

        let longStart = max(0, c - p.longWindow + 1)
        let long = history[longStart...c]
        let longMean = long.reduce(0, +) / Float(long.count)

        guard value >= localMean + p.delta * longMean, value > 0 else { return nil }
        let frameTime = historyTimes[c]
        guard frameTime - lastOnsetFrameTime >= p.minGap else { return nil }
        lastOnsetFrameTime = frameTime

        // Parabola through the peak and its neighbours: sub-frame position of the true maximum.
        let a = history[c - 1], b = value, d = history[c + 1]
        let denominator = a - 2 * b + d
        let fraction = denominator != 0 ? min(0.5, max(-0.5, 0.5 * (a - d) / denominator)) : 0
        return frameTime + (Double(fraction) * Double(p.hop) + Double(p.fftSize) / 2) / p.sampleRate
    }
}
