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

    func testAPauseStartsANewSegment() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0), counting: false)
        accumulator.add(fix(at: 1, north: 3))
        accumulator.add(fix(at: 2, north: 6))
        accumulator.add(fix(at: 3, north: 9), counting: false)
        accumulator.add(fix(at: 4, north: 12))
        accumulator.add(fix(at: 5, north: 15))

        XCTAssertEqual(accumulator.route.map(\.startsSegment), [nil, nil, true, nil])
        XCTAssertEqual(accumulator.route.segments.map(\.count), [2, 2])
    }

    func testRouteWithoutPausesIsOneSegment() throws {
        let route = (0...4).map { fix(at: Double($0), north: Double(3 * $0)).routePoint }
        XCTAssertEqual(route.segments, [route])
        XCTAssertEqual([RoutePoint]().segments, [])

        let json = try JSONEncoder().encode(route[0])
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("startsSegment"))
    }

    func testRecoversFromABadReferenceFix() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 500))
        XCTAssertEqual(accumulator.add(fix(at: 1, north: 0)), 0)
        accumulator.add(fix(at: 60, north: 0))
        XCTAssertEqual(accumulator.totalMeters, 500, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 2)
    }

    func testFixWithNoElapsedTimeIsIgnored() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        XCTAssertEqual(accumulator.add(fix(at: 0, north: 3)), 0)
        XCTAssertEqual(accumulator.totalMeters, 0)
    }
}
