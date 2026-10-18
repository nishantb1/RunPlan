import XCTest
@testable import RunCore

final class DistanceAccumulatorTests: XCTestCase {

    func testSumsDistanceBetweenFixes() {
        var accumulator = DistanceAccumulator()
        for second in 0...10 {
            accumulator.add(fix(at: Double(second), north: Double(3 * second)))
        }
        XCTAssertEqual(accumulator.totalMeters, 30, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 11)
    }

    func testIgnoresImpossibleJump() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        XCTAssertEqual(accumulator.add(fix(at: 2, north: 503)), 0)
        accumulator.add(fix(at: 3, north: 6))
        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 3)
    }

    func testPausedFixesMoveTheReferenceOnly() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        accumulator.add(fix(at: 2, north: 6), counting: false)
        accumulator.add(fix(at: 3, north: 9), counting: false)
        accumulator.add(fix(at: 4, north: 12))
        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 3)
    }

    func testFixWithNoElapsedTimeIsIgnored() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        XCTAssertEqual(accumulator.add(fix(at: 0, north: 3)), 0)
        XCTAssertEqual(accumulator.totalMeters, 0)
    }
}
