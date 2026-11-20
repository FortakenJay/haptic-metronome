import XCTest
@testable import TactusCore

final class TempoTests: XCTestCase {
    func testClampRoundsAndStaysInRange() {
        XCTAssertEqual(Tempo.clamped(119.4), 119)
        XCTAssertEqual(Tempo.clamped(119.5), 120)
        XCTAssertEqual(Tempo.clamped(5), 30)
        XCTAssertEqual(Tempo.clamped(999), 240)
        XCTAssertEqual(Tempo.clamped(.nan), Tempo.defaultBPM)
        XCTAssertEqual(Tempo.clamped(.infinity), Tempo.defaultBPM)
    }

    func testIntervalIsSixtyOverBPM() {
        XCTAssertEqual(Tempo.interval(for: 60), 1.0, accuracy: 1e-12)
        XCTAssertEqual(Tempo.interval(for: 240), 0.25, accuracy: 1e-12)
        XCTAssertEqual(Tempo.interval(for: 30), 2.0, accuracy: 1e-12)
    }

    func testEveryReachableTempoHasExactlyOneMarking() {
        let known: Set = [
            "Grave", "Largo", "Larghetto", "Adagio", "Andante",
            "Moderato", "Allegro", "Vivace", "Presto", "Prestissimo",
        ]
        for bpm in Tempo.range {
            XCTAssertTrue(known.contains(Tempo.marking(for: bpm)), "\(bpm)")
        }
    }

    func testMarkingEdges() {
        XCTAssertEqual(Tempo.marking(for: 30), "Grave")
        XCTAssertEqual(Tempo.marking(for: 60), "Larghetto")
        XCTAssertEqual(Tempo.marking(for: 100), "Andante")
        XCTAssertEqual(Tempo.marking(for: 120), "Allegro")
        XCTAssertEqual(Tempo.marking(for: 240), "Prestissimo")
    }

    func testDefaultIsReachable() {
        XCTAssertTrue(Tempo.range.contains(Tempo.defaultBPM))
    }

    func testFeelFlipsBetweenTheTwo() {
        XCTAssertEqual(Feel.light.next, .strong)
        XCTAssertEqual(Feel.strong.next, .light)
        XCTAssertEqual(Feel(rawValue: "strong"), .strong)
    }
}
