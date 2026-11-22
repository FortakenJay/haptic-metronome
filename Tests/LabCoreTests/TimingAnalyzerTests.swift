import XCTest
@testable import LabCore

final class TimingAnalyzerTests: XCTestCase {
    func testDeviationIsMeasuredFromTheNearestSubdivision() {
        var analyzer = TimingAnalyzer(beatZero: 10, interval: 0.6, subdivision: 4)
        let early = analyzer.add(onset: 10 + 0.15 * 2 - 0.020)   // third sixteenth, 20 ms early
        XCTAssertEqual(early?.slot, 2)
        XCTAssertEqual(early?.beat, 0)
        XCTAssertEqual(early!.deviation, -0.020, accuracy: 1e-9)
        let late = analyzer.add(onset: 10 + 0.6 * 3 + 0.012)       // beat 3, 12 ms late
        XCTAssertEqual(late?.beat, 3)
        XCTAssertEqual(late!.deviation, 0.012, accuracy: 1e-9)
    }

    func testFarFromTheGridIsUnmatched() {
        var analyzer = TimingAnalyzer(beatZero: 0, interval: 0.6, subdivision: 2)   // slots every 0.3 s
        XCTAssertNil(analyzer.add(onset: 0.15))      // halfway between slots
        XCTAssertNil(analyzer.add(onset: -5))        // long before the take: not even counted
        XCTAssertEqual(analyzer.unmatched, 1)
        XCTAssertTrue(analyzer.notes.isEmpty)
    }

    func testCalibrationOffsetIsSubtracted() {
        var analyzer = TimingAnalyzer(beatZero: 0, interval: 0.5, subdivision: 1, offset: 0.025)
        let note = analyzer.add(onset: 1.025)
        XCTAssertEqual(note!.deviation, 0, accuracy: 1e-9)
    }

    func testRecentDeviationIsTheMedianOfTheLastNotes() {
        var analyzer = TimingAnalyzer(beatZero: 0, interval: 1, subdivision: 1)
        for (beat, d) in [0.05, -0.01, -0.02, -0.03].enumerated() { analyzer.add(onset: Double(beat) + d) }
        XCTAssertEqual(analyzer.recentDeviation(last: 3)!, -0.02, accuracy: 1e-9)
        XCTAssertNil(TimingAnalyzer(beatZero: 0, interval: 1, subdivision: 1).recentDeviation())
    }

    /// Runs of sixteenths 30 ms early, chords on the beat 3 ms late: the summary should call out the runs.
    private func rushingTake() -> TimingAnalyzer {
        var analyzer = TimingAnalyzer(beatZero: 0, interval: 0.6, subdivision: 4)
        for bar in 0..<8 {
            let dense = (bar / 2) % 2 == 1
            for beat in 0..<4 {
                let t = Double(bar * 4 + beat) * 0.6
                if dense {
                    for s in 0..<4 { analyzer.add(onset: t + Double(s) * 0.15 - 0.030) }
                } else {
                    analyzer.add(onset: t + 0.003)
                }
            }
        }
        return analyzer
    }

    func testSummaryFindsRushingInTheRuns() {
        let summary = rushingTake().summary()
        XCTAssertEqual(summary.dense!, -0.030, accuracy: 1e-9)
        XCTAssertEqual(summary.sparse!, 0.003, accuracy: 1e-9)
        XCTAssertEqual(summary.headline, "You rush by 30 ms in the runs, on the beat elsewhere.")
        XCTAssertEqual(summary.worstStretch?.firstBar, 3)
        XCTAssertEqual(summary.worstStretch?.lastBar, 4)
        XCTAssertEqual(summary.noteCount, 16 * 4 + 16)
    }

    func testSummaryHeadlines() {
        var steady = TimingAnalyzer(beatZero: 0, interval: 0.5, subdivision: 1)
        for b in 0..<16 { steady.add(onset: Double(b) * 0.5 + (b % 2 == 0 ? 0.004 : -0.004)) }
        XCTAssertEqual(steady.summary().headline, "On the beat: within 10 ms overall.")
        XCTAssertNil(steady.summary().worstStretch)

        var dragging = TimingAnalyzer(beatZero: 0, interval: 0.5, subdivision: 1)
        for b in 0..<16 { dragging.add(onset: Double(b) * 0.5 + 0.022) }
        XCTAssertEqual(dragging.summary().headline, "You drag by 22 ms.")

        XCTAssertEqual(TimingAnalyzer(beatZero: 0, interval: 1, subdivision: 1).summary().headline,
                       "No notes heard. Play closer to the watch, or check Silent Mode.")
    }

    func testSpreadIsRobust() {
        var analyzer = TimingAnalyzer(beatZero: 0, interval: 0.5, subdivision: 1)
        for (b, d) in [0.0, 0.01, -0.01, 0.0, 0.01, -0.01, 0.15].enumerated() { analyzer.add(onset: Double(b) * 0.5 + d) }
        // One wild note (150 ms late, which is still within 35 % of 0.5 s) barely moves the robust spread.
        XCTAssertLessThan(analyzer.summary().spread!, 0.02)
    }

    func testCalibrationOffsetAndSelfNoise() {
        let beats = (0..<8).map { Double($0) * 0.75 }
        let onsets = beats.map { $0 + 0.028 } + [3.1]   // tapping 28 ms after the tap, plus one stray note
        XCTAssertEqual(Calibration.offset(onsets: onsets, beats: beats)!, 0.028, accuracy: 1e-9)
        XCTAssertNil(Calibration.offset(onsets: Array(onsets.prefix(3)), beats: beats))

        let silent = [0.0, 0.75, 1.5, 2.25]
        XCTAssertTrue(Calibration.hearsOwnTaps(onsets: [0.01, 0.76, 1.52], silentBeats: silent))
        XCTAssertFalse(Calibration.hearsOwnTaps(onsets: [0.4], silentBeats: silent))
    }

    func testEndToEndOnSyntheticAudio() {
        let take = SyntheticPiano.take(seed: 11)
        let detector = OnsetDetector(parameters: OnsetParameters(sampleRate: take.sampleRate))
        let onsets = detector.process(take.samples, startTime: 0)
        // Calibrate the way the app does: the detector's constant bias shows up as an offset.
        var calibration = TimingAnalyzer(beatZero: take.beats[0], interval: 0.6, subdivision: 4)
        onsets.forEach { calibration.add(onset: $0) }
        let offset = calibration.summary().sparse! - 0.003   // the chords were played 3 ms late

        var analyzer = TimingAnalyzer(beatZero: take.beats[0], interval: 0.6, subdivision: 4, offset: offset)
        onsets.forEach { analyzer.add(onset: $0) }
        let summary = analyzer.summary()
        XCTAssertEqual(summary.dense!, -0.030, accuracy: 0.004)
        XCTAssertTrue(summary.headline.hasPrefix("You rush by"), summary.headline)
        XCTAssertTrue(summary.headline.hasSuffix("in the runs, on the beat elsewhere."), summary.headline)
    }
}
