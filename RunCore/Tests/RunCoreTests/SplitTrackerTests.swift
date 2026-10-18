import XCTest
@testable import RunCore

final class SplitTrackerTests: XCTestCase {

    func testInterpolatesEachMile() {
        var tracker = SplitTracker()
        XCTAssertEqual(tracker.update(totalMeters: 1600, elapsed: 500), [])
        XCTAssertEqual(tracker.update(totalMeters: 1620, elapsed: 505), [
            Split(index: 1, distanceMeters: Pace.metersPerMile, durationSeconds: 502),
        ])
        XCTAssertEqual(tracker.update(totalMeters: 3300, elapsed: 1000), [
            Split(index: 2, distanceMeters: Pace.metersPerMile, durationSeconds: 474),
        ])

        let all = tracker.allSplits(totalMeters: 3300, elapsed: 1000)
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[2].index, 3)
        XCTAssertEqual(all[2].distanceMeters, 81.312, accuracy: 0.001)
        XCTAssertEqual(all[2].durationSeconds, 24)
    }

    func testSeveralMilesInOneUpdate() {
        var tracker = SplitTracker()
        XCTAssertEqual(tracker.update(totalMeters: 3300, elapsed: 1000).map(\.durationSeconds), [488, 488])
    }

    func testShortPartialSplitIsDropped() {
        var tracker = SplitTracker()
        _ = tracker.update(totalMeters: 1620, elapsed: 500)
        XCTAssertEqual(tracker.allSplits(totalMeters: 1620, elapsed: 500).count, 1)
    }
}
