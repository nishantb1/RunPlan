import XCTest
@testable import RunCore

final class PaceCueTests: XCTestCase {

    private func at(_ seconds: Double) -> Date { trackStart.addingTimeInterval(seconds) }

    func testCueAfterThirtySecondsOffAndEveryThirtyAfter() {
        var monitor = PaceCueMonitor()
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(0)))
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(29)))
        XCTAssertEqual(monitor.update(pace: 620, target: 600, now: at(30)), .speedUp)
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(31)))
        XCTAssertEqual(monitor.update(pace: 620, target: 600, now: at(60)), .speedUp)
    }

    func testFifteenSecondsOffIsWithinTolerance() {
        var monitor = PaceCueMonitor()
        for second in [0.0, 30, 60] {
            XCTAssertNil(monitor.update(pace: 615, target: 600, now: at(second)))
        }
        var justOutside = PaceCueMonitor()
        _ = justOutside.update(pace: 616, target: 600, now: at(0))
        XCTAssertEqual(justOutside.update(pace: 616, target: 600, now: at(30)), .speedUp)
    }

    func testOnPaceOrDirectionChangeRestartsTheTimer() {
        var monitor = PaceCueMonitor()
        _ = monitor.update(pace: 620, target: 600, now: at(0))
        XCTAssertNil(monitor.update(pace: 610, target: 600, now: at(20)))
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(40)))
        XCTAssertNil(monitor.update(pace: 580, target: 600, now: at(60)))
        XCTAssertNil(monitor.update(pace: 580, target: 600, now: at(89)))
        XCTAssertEqual(monitor.update(pace: 580, target: 600, now: at(90)), .slowDown)
    }

    func testNoCueWithoutPaceOrTargetOrAfterReset() {
        var monitor = PaceCueMonitor()
        _ = monitor.update(pace: 620, target: 600, now: at(0))
        XCTAssertNil(monitor.update(pace: nil, target: 600, now: at(30)))
        XCTAssertNil(monitor.update(pace: 620, target: nil, now: at(31)))
        _ = monitor.update(pace: 620, target: 600, now: at(32))
        monitor.reset()
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(62)))
    }

    func testOutdoorCueWording() {
        XCTAssertEqual(CueText.splitAnnouncement(Split(index: 2, distanceMeters: Pace.metersPerMile, durationSeconds: 572)), "Mile 2, 9 minutes 32 seconds.")
        XCTAssertEqual(CueText.splitAnnouncement(Split(index: 1, distanceMeters: Pace.metersPerMile, durationSeconds: 600)), "Mile 1, 10 minutes.")
        XCTAssertEqual(CueText.paceCue(.speedUp), "Pick up the pace.")
        XCTAssertEqual(CueText.paceCue(.slowDown), "Ease off the pace.")
    }
}
