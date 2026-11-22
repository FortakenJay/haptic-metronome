import XCTest
@testable import LabCore

final class OnsetDetectorTests: XCTestCase {
    /// Runs the detector over `samples` in chunks of `chunk` (like audio buffers) and returns the onsets.
    private func detect(_ samples: [Float], sampleRate: Double, chunk: Int = 1024, start: Double = 0) -> [Double] {
        let detector = OnsetDetector(parameters: OnsetParameters(sampleRate: sampleRate))
        var onsets: [Double] = []
        var i = 0
        while i < samples.count {
            let end = min(samples.count, i + chunk)
            onsets += detector.process(Array(samples[i..<end]), startTime: start + Double(i) / sampleRate)
            i = end
        }
        return onsets
    }

    /// Pairs each true onset with the nearest detection within 50 ms (each detection used once).
    private func match(_ detected: [Double], _ truth: [Double]) -> [(truth: Int, error: Double)] {
        var used = Set<Int>(), pairs: [(Int, Double)] = []
        for (i, t) in truth.enumerated() {
            guard let j = detected.indices.min(by: { abs(detected[$0] - t) < abs(detected[$1] - t) }),
                  abs(detected[j] - t) <= 0.05, !used.contains(j) else { continue }
            used.insert(j)
            pairs.append((i, detected[j] - t))
        }
        return pairs
    }

    func testParametersFollowTheSampleRate() {
        XCTAssertEqual(OnsetParameters(sampleRate: 48_000).fftSize, 1024)
        XCTAssertEqual(OnsetParameters(sampleRate: 48_000).hop, 256)
        XCTAssertEqual(OnsetParameters(sampleRate: 16_000).fftSize, 512)
    }

    func testFindsNearlyEveryNoteWithMillisecondTiming() {
        let take = SyntheticPiano.take()
        let detected = detect(take.samples, sampleRate: take.sampleRate)
        let pairs = match(detected, take.onsets)
        let recall = Double(pairs.count) / Double(take.onsets.count)
        let precision = Double(pairs.count) / Double(detected.count)
        XCTAssertGreaterThanOrEqual(recall, 0.95, "recall \(recall)")
        XCTAssertGreaterThanOrEqual(precision, 0.90, "precision \(precision)")

        // Constant bias doesn't matter (calibration removes it); the spread around it does.
        let errors = pairs.map(\.error)
        let bias = Stats.median(errors)!
        let spread = 1.4826 * Stats.median(errors.map { abs($0 - bias) })!
        XCTAssertLessThan(abs(bias), 0.006, "bias \(bias)")
        XCTAssertLessThan(spread, 0.003, "spread \(spread)")
    }

    func testIgnoresTheWatchsOwnTapticBuzz() {
        let detected = detect(SyntheticPiano.silence(), sampleRate: 16_000)
        XCTAssertEqual(detected.count, 0, "\(detected)")
    }

    func testSameResultsWhateverTheMicLevel() {
        let loud = SyntheticPiano.take(seed: 5, gain: 1)
        let quiet = SyntheticPiano.take(seed: 5, gain: 0.01)
        let a = detect(loud.samples, sampleRate: 16_000), b = detect(quiet.samples, sampleRate: 16_000)
        XCTAssertEqual(Double(a.count), Double(b.count), accuracy: 2)
        XCTAssertGreaterThanOrEqual(Double(match(b, quiet.onsets).count) / Double(quiet.onsets.count), 0.95)
    }

    func testBufferSizeDoesNotChangeTheOnsets() {
        let take = SyntheticPiano.take(bars: 4, seed: 7)
        let big = detect(take.samples, sampleRate: 16_000, chunk: 4096, start: 100)
        let odd = detect(take.samples, sampleRate: 16_000, chunk: 333, start: 100)
        XCTAssertEqual(big.count, odd.count)
        for (x, y) in zip(big, odd) { XCTAssertEqual(x, y, accuracy: 1e-9) }
        XCTAssertGreaterThan(big.first ?? 0, 100, "times are on the caller's clock")
    }

    func testAGapInTheStreamDoesNotShiftLaterTimes() {
        let take = SyntheticPiano.take(bars: 4, seed: 9)
        let detector = OnsetDetector(parameters: OnsetParameters(sampleRate: 16_000))
        let half = take.samples.count / 2
        var onsets = detector.process(Array(take.samples[..<half]), startTime: 0)
        // The second half arrives with its true timestamp after 30 dropped samples.
        onsets += detector.process(Array(take.samples[(half + 30)...]), startTime: Double(half + 30) / 16_000)
        let later = take.onsets.filter { $0 > Double(half) / 16_000 + 0.1 }
        let pairs = match(onsets, later)
        XCTAssertGreaterThanOrEqual(Double(pairs.count) / Double(later.count), 0.9)
        XCTAssertLessThan(abs(Stats.median(pairs.map(\.error))!), 0.006)
    }
}
