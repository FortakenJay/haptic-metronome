import XCTest
@testable import TactusCore

final class BeatClockTests: XCTestCase {
    func testFirstBeatIsDueAtTheStart() {
        let clock = BeatClock(startingAt: 0, bpm: 120)
        XCTAssertEqual(clock.nextBeat, 0)
        XCTAssertEqual(clock.interval, 0.5, accuracy: 1e-12)
    }

    func testBeatsAreSpacedFromThePlanNotFromWhenTheyFired() {
        var clock = BeatClock(startingAt: 0, bpm: 120)
        // Every buzz fires 30 ms late. The plan must not drift: beat n is still due at n × 0.5 s.
        for n in 1...1_000 {
            clock.beatPlayed(at: clock.nextBeat + 0.03)
            XCTAssertEqual(clock.nextBeat, Double(n) * 0.5, accuracy: 1e-9)
        }
    }

    func testAStallSkipsMissedBeatsInsteadOfBurstingThem() {
        var clock = BeatClock(startingAt: 0, bpm: 60)   // a beat every second
        clock.beatPlayed(at: 0)                          // beat 0 played on time; beat 1 due at 1.0
        clock.beatPlayed(at: 3.4)                        // beat 1 only got played at 3.4 s
        XCTAssertEqual(clock.nextBeat, 4.0, accuracy: 1e-12, "beats 2 and 3 are skipped, still on the grid")
    }

    func testALateBeatInsideOneIntervalSkipsNothing() {
        var clock = BeatClock(startingAt: 0, bpm: 60)
        clock.beatPlayed(at: 0.9)
        XCTAssertEqual(clock.nextBeat, 1.0, accuracy: 1e-12)
    }

    func testTempoChangeLandsOneNewIntervalAfterTheLastBeat() {
        var clock = BeatClock(startingAt: 0, bpm: 60)
        clock.beatPlayed(at: 0)          // last beat at 0, next due at 1.0
        clock.setTempo(120)
        XCTAssertEqual(clock.interval, 0.5, accuracy: 1e-12)
        XCTAssertEqual(clock.nextBeat, 0.5, accuracy: 1e-12)

        clock.setTempo(30)
        XCTAssertEqual(clock.nextBeat, 2.0, accuracy: 1e-12)
    }

    func testTempoChangesDoNotAccumulateError() {
        var clock = BeatClock(startingAt: 0, bpm: 100)
        clock.beatPlayed(at: 0)
        for bpm in [101, 99, 150, 30, 240, 100] { clock.setTempo(bpm) }
        XCTAssertEqual(clock.nextBeat, 0.6, accuracy: 1e-12, "still one 100 BPM interval after the last beat")
    }
}
