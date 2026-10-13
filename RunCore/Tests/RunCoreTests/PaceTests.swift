import XCTest
@testable import RunCore

final class PaceTests: XCTestCase {

    func testMphFromPaceRoundsToOneDecimal() {
        XCTAssertEqual(Pace.mph(fromSecondsPerMile: 766), 4.7)
        XCTAssertEqual(Pace.mph(fromSecondsPerMile: 1440), 2.5)
        XCTAssertEqual(Pace.mph(fromSecondsPerMile: 600), 6.0)
    }

    func testPaceFromMph() {
        XCTAssertEqual(Pace.secondsPerMile(fromMph: 4.7), 766)
        XCTAssertEqual(Pace.secondsPerMile(fromMph: 6.0), 600)
    }

    func testClockFormatting() {
        XCTAssertEqual(Pace.clock(0), "0:00")
        XCTAssertEqual(Pace.clock(65), "1:05")
        XCTAssertEqual(Pace.clock(766), "12:46")
        XCTAssertEqual(Pace.clock(3725), "1:02:05")
    }

    func testNegativeClockClampsToZero() {
        XCTAssertEqual(Pace.clock(-4), "0:00")
    }

    func testAveragePace() {
        XCTAssertEqual(Pace.secondsPerMile(distanceMeters: 1609.344, durationSeconds: 600), 600)
        XCTAssertNil(Pace.secondsPerMile(distanceMeters: 0, durationSeconds: 600))
    }

    func testMileConversions() {
        XCTAssertEqual(Pace.miles(fromMeters: 5000), 3.107, accuracy: 0.001)
        XCTAssertEqual(Pace.meters(fromMiles: 3.1), 4988.97, accuracy: 0.01)
    }
}
