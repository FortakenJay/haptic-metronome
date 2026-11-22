import XCTest
@testable import TactusCore

final class MeterTests: XCTestCase {
    func testEveryMeterIsValidAndUnique() {
        var ids = Set<String>()
        for meter in Meter.all {
            XCTAssertEqual(meter.groups.reduce(0, +), meter.beats, meter.id)
            XCTAssertTrue(ids.insert(meter.id).inserted, "duplicate \(meter.id)")
            XCTAssertEqual(Meter.with(id: meter.id), meter)
        }
        XCTAssertEqual(Meter.all.first, .off)
        XCTAssertNil(Meter.with(id: "13/16"))
    }

    func testFiveEightThreeTwoAccentsBeatsOneAndFour() {
        let meter = Meter(5, 8, groups: [3, 2])
        let taps = (0..<10).map { meter.tap(atBeat: $0, feel: .strong) }
        XCTAssertEqual(taps, [.strong, .light, .light, .strong, .light, .strong, .light, .light, .strong, .light])
        XCTAssertEqual(meter.accent(atBeat: 0), .downbeat)
        XCTAssertEqual(meter.accent(atBeat: 3), .group)
        XCTAssertEqual(meter.accent(atBeat: 5), .downbeat)   // next bar
    }

    func testSevenEightGroupings() {
        XCTAssertEqual(Meter(7, 8, groups: [2, 2, 3]).groupStarts, [0, 2, 4])
        XCTAssertEqual(Meter(7, 8, groups: [3, 2, 2]).groupStarts, [0, 3, 5])
        XCTAssertEqual(Meter(7, 8, groups: [2, 3, 2]).groupStarts, [0, 2, 5])
    }

    func testPlainMetersAccentOnlyBeatOne() {
        let fourFour = Meter(4, 4)
        XCTAssertEqual((0..<8).map { fourFour.tap(atBeat: $0, feel: .light) },
                       [.strong, .light, .light, .light, .strong, .light, .light, .light])
        XCTAssertNil(fourFour.groupingLabel)
    }

    func testOffFollowsFeelOnEveryBeat() {
        XCTAssertEqual((0..<4).map { Meter.off.tap(atBeat: $0, feel: .light) }, [.light, .light, .light, .light])
        XCTAssertEqual((0..<4).map { Meter.off.tap(atBeat: $0, feel: .strong) }, [.strong, .strong, .strong, .strong])
        XCTAssertEqual(Meter.off.accent(atBeat: 0), .plain)
    }

    func testLabels() {
        let meter = Meter(7, 8, groups: [2, 2, 3])
        XCTAssertEqual(meter.id, "7/8:2+2+3")
        XCTAssertEqual(meter.label, "7/8")
        XCTAssertEqual(meter.groupingLabel, "2+2+3")
        XCTAssertEqual(meter.spokenLabel, "7/8, 2 plus 2 plus 3")
        XCTAssertTrue(meter.countsEighths)
        XCTAssertEqual(Meter.off.id, "off")
        XCTAssertEqual(Meter(4, 4).id, "4/4")
    }

    func testPositionWrapsAcrossBars() {
        let meter = Meter(5, 4, groups: [3, 2])
        XCTAssertEqual((0..<11).map { meter.position(ofBeat: $0) }, [0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0])
    }
}
